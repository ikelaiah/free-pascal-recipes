{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Some useful string routines.                                             *
*                                                                           *
*   Copyright(c) 2018-2024 A.Koverdyaev(avk)                                *
*                                                                           *
*   This code is free software; you can redistribute it and/or modify it    *
*   under the terms of the Apache License, Version 2.0;                     *
*   You may obtain a copy of the License at                                 *
*     http://www.apache.org/licenses/LICENSE-2.0.                           *
*                                                                           *
*  Unless required by applicable law or agreed to in writing, software      *
*  distributed under the License is distributed on an "AS IS" BASIS,        *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
*  See the License for the specific language governing permissions and      *
*  limitations under the License.                                           *
*                                                                           *
*****************************************************************************}
unit lgStrHelpers;

{$mode objfpc}{$H+}
{$MODESWITCH TYPEHELPERS}
{$MODESWITCH ADVANCEDRECORDS}
{$MODESWITCH NESTEDPROCVARS}
{$INLINE ON}

interface

uses

  Classes, SysUtils, Math, uRegExpr,
  lgUtils,
  lgHelpers,
  lgArrayHelpers,
  lgAbstractContainer,
  lgVector,
  lgQueue,
  lgMiscUtils,
  lgStrConst;


type
  TStrSlice = record
    Ptr: PAnsiChar;
    Count: SizeInt;
    constructor Init(p: PAnsiChar; aCount: SizeInt);
    class operator := (const s: string): TStrSlice; inline;
    class operator := (const s: TStrSlice): string; inline;
    class operator = (const L, R: TStrSlice): Boolean; inline;
    class operator = (const L: TStrSlice; const R: string): Boolean; inline;
  end;

  TAnsiStrHelper = type helper(TAStrHelper) for string
  private
  type
    TStrEnumerable = class(specialize TGAutoEnumerable<string>)
    strict private
      FValue: string;
      FStartIndex,
      FLastIndex: SizeInt;
      FStopChars: TSysCharSet;
    protected
      function  GetCurrent: string; override;
    public
      constructor Create(const aValue: string; const aStopChars: TSysCharSet);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TSliceEnumerable = class(specialize TGAutoEnumerable<TStrSlice>)
    strict private
      FValue: string;
      FStartIndex,
      FLastIndex: SizeInt;
      FStopChars: TSysCharSet;
    protected
      function  GetCurrent: TStrSlice; override;
    public
      constructor Create(const aValue: string; const aStopChars: TSysCharSet);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  public
  type
    IStrEnumerable   = specialize IGEnumerable<string>;
    ISliceEnumerable = specialize IGEnumerable<TStrSlice>;

    TWordSliceEnumerator = record
    strict private
      FValue: string;
      FStartIndex,
      FLastIndex: SizeInt;
      FStopChars: TSysCharSet;
    private
      procedure Init(const aValue: string; const aStopChars: TSysCharSet); inline;
      function  GetCurrent: TStrSlice; inline;
    public
      function  MoveNext: Boolean; inline;
      property  Current: TStrSlice read GetCurrent;
    end;

    TWordSliceEnum = record
    strict private
      FValue: string;
      FStopChars: TSysCharSet;
    private
      procedure Init(const aValue: string; const aStopChars: TSysCharSet); inline;
    public
      function GetEnumerator: TWordSliceEnumerator; inline;
      function ToArray: specialize TGArray<TStrSlice>;
    end;

  const
    WhiteSpaces     = [#0..' '];
    AsciiDelimiters = [#0..#255] - ['a'..'z', 'A'..'Z', '0'..'9', '_'];
  { Join2 is similar to Join() from SysUtils, but does not raise exceptions,
    returning an empty string in such cases }
    class function Join2(const aSeparator: string; const aValues: array of string): string; static;
    class function Join2(const aSeparator: string; const aValues: array of string;
                         aFrom, aCount: SizeInt): string; static;
    class function Join(const aSeparator: string; const aValues: array of TStrSlice): string; static; overload;
    class function Join(const aSeparator: string; const aValues: array of TStrSlice;
                        aFrom, aCount: SizeInt): string; static; overload;
    class function Join(const aSeparator: string; aValues: IStrEnumerable): string; static; overload;
    class function Join(const aSeparator: string; aValues: ISliceEnumerable): string; static; overload;
    function StripWhiteSpaces: string; inline;
    function StripChar(aChar: AnsiChar): string;
    function StripChars(const aChars: TSysCharSet): string;
    // only single byte delimiters allowed
    function Words(const aStopChars: TSysCharSet = AsciiDelimiters): IStrEnumerable; inline;
    function WordSlices(const aStopChars: TSysCharSet = AsciiDelimiters): ISliceEnumerable; inline;
    function WordSliceEnum(const aStopChars: TSysCharSet = AsciiDelimiters): TWordSliceEnum; inline;
  end;

  TRegexMatch = class
  protected
  type
    TStrEnumerable = class(specialize TGAutoEnumerable<string>)
    private
      FRegex: TRegExpr;
      FInputString: string;
      FInCycle: Boolean;
    protected
      function  GetCurrent: string; override;
    public
      constructor Create(aRegex: TRegExpr; const s: string);
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  var
    FRegex: TRegExpr;
    function  GetExpression: string;
    function  GetModifierStr: string;
    procedure SetExpression(const aValue: string);
    procedure SetModifierStr(const aValue: string);
  public
  type
    IStrEnumerable = specialize IGEnumerable<string>;

    constructor Create;
    constructor Create(const aRegExpression: string);
    constructor Create(const aRegExpression, aModifierStr: string);
    destructor Destroy; override;
    function Matches(const aValue: string): IStrEnumerable; inline;
    property Expression: string read GetExpression write SetExpression;
    property ModifierStr: string read GetModifierStr write SetModifierStr;
  end;

  TStringListHelper = class helper for TStringList
  public
  type
    IStrEnumerable = specialize IGEnumerable<string>;

    function AsEnumerable: IStrEnumerable; inline;
  end;

  { TBmSearch implements Boyer-Moore exact string matching algorithm  in a variant somewhat
    similar to Fast-Search from D.Cantone, S.Faro: "Fast-Search: A New Efﬁcient Variant of
    the Boyer-Moore String Matching Algorithm" 2003 }
  TBmSearch = record
  private
  type
    PMatcher = ^TBmSearch;

    TStrEnumerator = record
    private
      FCurrIndex: SizeInt;
      FHeap: rawbytestring;
      FMatcher: PMatcher;
      function GetCurrent: SizeInt; inline;
    public
      function MoveNext: Boolean;
      property Current: SizeInt read GetCurrent;
    end;

    TByteEnumerator = record
      FCurrIndex,
      FHeapLen: SizeInt;
      FHeap: PByte;
      FMatcher: PMatcher;
      function GetCurrent: SizeInt; inline;
    public
      function MoveNext: Boolean;
      property Current: SizeInt read GetCurrent;
    end;

  var
    FBcShift: array[Byte] of Integer; //bad character shifts
    FGsShift: array of Integer;       //good suffix shifts
    FNeedle: rawbytestring;
    function  DoFind(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
    function  FindNext(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
    function  Find(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
  public
  type
    TIntArray = array of SizeInt;

    TStrMatches = record
    private
      FHeap: rawbytestring;
      FMatcher: PMatcher;
    public
      function GetEnumerator: TStrEnumerator; inline;
    end;

    TByteMatches = record
    private
      FHeapLen: SizeInt;
      FHeap: PByte;
      FMatcher: PMatcher;
    public
      function GetEnumerator: TByteEnumerator; inline;
    end;
  { initializes the algorithm with a search pattern }
    constructor Create(const aPattern: rawbytestring);
    constructor Create(const aPattern: array of Byte);
  { returns an enumerator of indices(1-based) of all occurrences of pattern in s }
    function Matches(const s: rawbytestring): TStrMatches; inline;
  { returns an enumerator of indices(0-based) of all occurrences of pattern in a }
    function Matches(const a: array of Byte): TByteMatches;
  { returns the index of the next occurrence of the pattern in s,
    starting at index aOffset(1-based) or 0 if there is no occurrence;
    to get the index of the next occurrence, you need to pass in aOffset
    the index of the previous occurrence, increased by one }
    function NextMatch(const s: rawbytestring; aOffset: SizeInt = 1): SizeInt;
  { returns the index of the next occurrence of the pattern in a,
    starting at index aOffset(0-based) or -1 if there is no occurrence;
    to get the index of the next occurrence, you need to pass in aOffset
    the index of the previous occurrence, increased by one }
    function NextMatch(const a: array of Byte; aOffset: SizeInt = 0): SizeInt;
  { returns in an array the indices(1-based) of all occurrences of the pattern in s }
    function FindMatches(const s: rawbytestring): TIntArray;
  { returns in an array the indices(0-based) of all occurrences of the pattern in a }
    function FindMatches(const a: array of Byte): TIntArray;
  end;

  { TBmhrSearch implements a variant of the Boyer-Moore-Horspool-Raita algorithm;
    degrades noticeably on short alphabets }
  TBmhrSearch = record
  private
  type
    PMatcher = ^TBmhrSearch;

    TStrEnumerator = record
    private
      FCurrIndex: SizeInt;
      FHeap: rawbytestring;
      FMatcher: PMatcher;
      function GetCurrent: SizeInt; inline;
    public
      function MoveNext: Boolean;
      property Current: SizeInt read GetCurrent;
    end;

    TByteEnumerator = record
      FCurrIndex,
      FHeapLen: SizeInt;
      FHeap: PByte;
      FMatcher: PMatcher;
      function GetCurrent: SizeInt; inline;
    public
      function MoveNext: Boolean;
      property Current: SizeInt read GetCurrent;
    end;
  var
    FBcShift: array[Byte] of Integer; //bad character shifts
    FNeedle: rawbytestring;
    function  Find(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
    function  FindNext(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
  public
  type
    TIntArray = array of SizeInt;

    TStrMatches = record
    private
      FHeap: rawbytestring;
      FMatcher: PMatcher;
    public
      function GetEnumerator: TStrEnumerator; inline;
    end;

    TByteMatches = record
    private
      FHeapLen: SizeInt;
      FHeap: PByte;
      FMatcher: PMatcher;
    public
      function GetEnumerator: TByteEnumerator; inline;
    end;
  { initializes the algorithm with a search pattern }
    constructor Create(const aPattern: rawbytestring);
    constructor Create(const aPattern: array of Byte);
  { returns an enumerator of indices(1-based) of all occurrences of pattern in s }
    function Matches(const s: rawbytestring): TStrMatches; inline;
  { returns an enumerator of indices(0-based) of all occurrences of pattern in a }
    function Matches(const a: array of Byte): TByteMatches;
  { returns the index of the next occurrence of the pattern in s,
    starting at index aOffset(1-based) or 0 if there is no occurrence;
    to get the index of the next occurrence, you need to pass in aOffset
    the index of the previous occurrence, increased by one }
    function NextMatch(const s: rawbytestring; aOffset: SizeInt = 1): SizeInt;
  { returns the index of the next occurrence of the pattern in a,
    starting at index aOffset(0-based) or -1 if there is no occurrence;
    to get the index of the next occurrence, you need to pass in aOffset
    the index of the previous occurrence, increased by one }
    function NextMatch(const a: array of Byte; aOffset: SizeInt = 0): SizeInt;
  { returns in an array the indices(1-based) of all occurrences of the pattern in s }
    function FindMatches(const s: rawbytestring): TIntArray;
  { returns in an array the indices(0-based) of all occurrences of the pattern in a }
    function FindMatches(const a: array of Byte): TIntArray;
  end;

  TCaseMapTable = array[Byte] of Byte;
{ must convert the chars to a single case, no matter which one }
  TCaseMapFun = function(c: Char): Char;

  { TBmSearchCI implements case insensitive variant of TBmSearch;
    for single-byte encodings only }
  TBmSearchCI = record
  private
  type
    PMatcher = ^TBmSearchCI;

    TEnumerator = record
    private
      FCurrIndex: SizeInt;
      FHeap: rawbytestring;
      FMatcher: PMatcher;
      function GetCurrent: SizeInt; inline;
    public
      function MoveNext: Boolean;
      property Current: SizeInt read GetCurrent;
    end;

  var
    FCaseMap: TCaseMapTable;
    FBcShift: array[Byte] of Integer; //bad character shifts
    FGsShift: array of Integer;       //good suffix shifts
    FNeedle: rawbytestring;
    procedure FillMap;
    procedure FillMap(aMap: TCaseMapFun);
    procedure FillMap(const aTable: TCaseMapTable);
    function  DoFind(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
    function  FindNext(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
    function  Find(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
  public
  type
    TIntArray = array of SizeInt;

    TMatches = record
    private
      FHeap: rawbytestring;
      FMatcher: PMatcher;
    public
      function GetEnumerator: TEnumerator; inline;
    end;
  { initializes the algorithm with a search pattern }
    constructor Create(const aPattern: rawbytestring);
  { initializes the algorithm with a search pattern and custom case map }
    constructor Create(const aPattern: rawbytestring; aMap: TCaseMapFun);
    constructor Create(const aPattern: rawbytestring; const aTable: TCaseMapTable);
  { sets a new search pattern; it is assumed that the algorithm was previously initialized }
    procedure Update(const aPattern: rawbytestring);
  { returns an enumerator of indices(1-based) of all occurrences of pattern in s }
    function Matches(const s: rawbytestring): TMatches; inline;
  { returns the index of the next occurrence of the pattern in s,
    starting at index aOffset(1-based) or 0 if there is no occurrence;
    to get the index of the next occurrence, you need to pass in aOffset
    the index of the previous occurrence, increased by one }
    function NextMatch(const s: rawbytestring; aOffset: SizeInt = 1): SizeInt;
  { returns in an array the indices(1-based) of all occurrences of the pattern in s }
    function FindMatches(const s: rawbytestring): TIntArray;
  end;

  { TACSearchFsm: Aho-Corasick automation(DFA) for the exact set matching problem;
    does not store dictionary elements explicitly, instead storing their indices
    in the initializing pattern list }
  TACSearchFsm = class
  type
    TMatch         = LgUtils.TIndexMatch;
    TOnMatch       = specialize TGOnTest<TMatch>;
    TNestMatch     = specialize TGNestTest<TMatch>;
    TMatchArray    = specialize TGArray<TMatch>;
    IStrEnumerable = specialize IGEnumerable<rawbytestring>;
  private
  type
    TNode = record
      NextMove: array of Int32;// transition table
      Output,                  // output link
      Index,                   // index in the input list(if node is teminal)
      Length: Int32;           // length in bytes(Length > 0 indicates a terminal node)
    end;
    TSortHelper = specialize TGRegularTimSort<TMatch>;
    TVectHelper = specialize TGRegularVectorHelper<TMatch>;
  private
    FTrie: array of TNode;
    FCharMap: array[Byte] of SmallInt;
    FOnMatchHandler: TOnMatch;
    FNestMatchHandler: TNestMatch;
    FOnMatch: TOnMatch;
    FNodeCount,
    FWordCount: SizeInt;
    FAlphabetSize: SizeInt;
    function  TestOnMatch(const m: TMatch): Boolean;
    function  TestNestMatch(const m: TMatch): Boolean;
    procedure RegisterMatchHandler(h: TOnMatch);
    procedure RegisterMatchHandler(h: TNestMatch);
    function  NewNode: SizeInt;
    procedure BuildCharMap(const aList: array of rawbytestring);
    procedure AddPattern(const aValue: rawbytestring; aIndex: SizeInt);
    procedure BuildFsm;
    function  TestInput(const s: rawbytestring; var aOffset, aCount: SizeInt): Boolean; inline;
    function  DoFindNoOverlap(const s: rawbytestring; aOffset, aCount: SizeInt): TMatchArray;
    function  DoFindAll(const s: rawbytestring; aOffset, aCount: SizeInt): TMatchArray;
    procedure DoSearch(const s: rawbytestring; aOffset, aCount: SizeInt);
  public
    class procedure DoFilterMatches(var aMatches: TMatchArray; aMode: TSetMatchMode); static;
  public
    class function FilterMatches(const aSource: array of TMatch; aMode: TSetMatchMode): TMatchArray; static;
    constructor Create(const aPatternList: array of rawbytestring);
    constructor Create(aPatternEnum: IStrEnumerable);
    constructor Create(aFsm: TACSearchFsm);
  { returns the index of the pattern in the input list if the instance contains such a pattern,
    otherwise returns -1 }
    function  IndexOfPattern(const aValue: rawbytestring): SizeInt;
  { returns True if the instance contains such a pattern, False otherwise }
    function  IsMatch(const aValue: rawbytestring): Boolean;
  { returns the first(according to the specified mode) match, if any, otherwise returns stub(0,0,-1) }
    function  FirstMatch(const aText: rawbytestring; aMode: TSetMatchMode = smmDefault;
                         aOffset: SizeInt = 1; aCount: SizeInt = 0): TMatch;
  { returns an array of all matches found in the string aText(according to the specified mode),
    starting at position aOffset within aCount bytes;
    any value of aCount < 1 implies a search to the end of the text }
    function  FindMatches(const aText: rawbytestring; aMode: TSetMatchMode = smmDefault;
                          aOffset: SizeInt = 1; aCount: SizeInt = 0): TMatchArray;
  { searches in the string aText starting at position aOffset within aCount bytes, passing
    all found matches to the callback aOnMatch(); immediately exits the procedure if aOnMatch()
    returns False; any value of aCount < 1 implies a search to the end of the text;
    if aOnMatch = nil then just exits the procedure }
    procedure Search(const aText: rawbytestring; aOnMatch: TOnMatch; aOffset: SizeInt = 1; aCount: SizeInt = 0);
    procedure Search(const aText: rawbytestring; aOnMatch: TNestMatch; aOffset: SizeInt = 1; aCount: SizeInt = 0);
  { returns True if at least one match is found in the string aText, starting at position aOffset
    within aCount bytes; any value of aCount < 1 implies a search to the end of the text }
    function  ContainsMatch(const aText: rawbytestring; aOffset: SizeInt = 1; aCount: SizeInt = 0): Boolean;
    property  NodeCount: SizeInt read FNodeCount;
    property  PatternCount: SizeInt read FWordCount;
    property  AlphabetSize: SizeInt read FAlphabetSize;
  end;

{ the following functions are only suitable for single-byte encodings }

{ returns True if aSub is a subsequence of aStr, False otherwise }
  function IsSubSequence(const aStr, aSub: rawbytestring): Boolean; inline;
{ returns the longest common subsequence(LCS) of sequences L and R, reducing the task to LIS,
  with O(SLogN) time complexity, where S is the number of the matching pairs in L and R;
  inspired by Dan Gusfield "Algorithms on Strings, Trees and Sequences", section 12.5 }
  function LcsGus(const L, R: rawbytestring): rawbytestring;
  function LcsGus(const L, R: array of Byte): TBytes;
{ recursive, returns the longest common subsequence(LCS) of sequences L and R;
  uses Kumar-Rangan algorithm for LCS with space complexity O(n) and time complexity O(n(m-p)), where
  m = Min(length(L), length(R)), n = Max(length(L), length(R)), and p is the length of the LCS computed }
  function LcsKR(const L, R: rawbytestring): rawbytestring;
  function LcsKR(const L, R: array of Byte): TBytes;
{ recursive, returns the longest common subsequence(LCS) of sequences L and R;
  uses Myers algorithm for LCS with space complexity O(m+n) and time complexity O((m+n)*d), where
  n and m are the lengths of L and R respectively, and d is the size of the minimum edit script
  for L and R (d = m + n - 2*p, where p is the lenght of the LCS) }
  function LcsMyers(const L, R: rawbytestring): rawbytestring;
  function LcsMyers(const L, R: array of Byte): TBytes;
{ returns the Levenshtein distance between L and R; used a simple dynamic programming
  algorithm with O(mn) time complexity, where m and n are the lengths of L and R respectively,
  and O(Max(m, n)) space complexity }
  function LevDistance(const L, R: rawbytestring): SizeInt;
  function LevDistance(const L, R: array of Byte): SizeInt;
{ returns the Levenshtein distance between L and R; a Pascal translation(well, almost :))
  of github.com/vaadin/gwt/dev/util/editdistance/ModifiedBerghelRoachEditDistance.java -
  a modified version of algorithm described by Berghel and Roach with O(min(n, m)*d)
  worst-case time complexity, where n and m are the lengths of L and R respectively
  and d is the edit distance computed }
  function LevDistanceMbr(const L, R: rawbytestring): SizeInt;
  function LevDistanceMbr(const L, R: array of Byte): SizeInt;
{ the same as above; the aLimit parameter indicates the maximum expected distance,
  if this value is exceeded when calculating the distance, then the function exits
  immediately and returns -1; if aLimit < 0 it will be computed dynamically }
  function LevDistanceMbr(const L, R: rawbytestring; aLimit: SizeInt): SizeInt;
  function LevDistanceMbr(const L, R: array of Byte; aLimit: SizeInt): SizeInt;
{ returns the Levenshtein distance between L and R; uses the Myers bit-vector algorithm
  with O(dn/w) time complexity, where n is Max(|L|, |R|), d is edit distance computed,
  and w is the size of a computer word }
  function LevDistanceMyers(const L, R: rawbytestring): SizeInt;
  function LevDistanceMyers(const L, R: array of Byte): SizeInt;
{ the same as above; the aLimit parameter indicates the maximum expected distance,
  if this value is exceeded when calculating the distance, then the function exits
  immediately and returns -1; if aLimit < 0 it will be computed dynamically }
  function LevDistanceMyers(const L, R: rawbytestring; aLimit: SizeInt): SizeInt;
  function LevDistanceMyers(const L, R: array of Byte; aLimit: SizeInt): SizeInt;
{ the LCS edit distance allows only two operations: insertion and deletion; uses slightly
  modified Myers algorithm with O((|L|+|R|)D) time complexity and linear space complexity
  from Eugene W. Myers(1986), "An O(ND) Difference Algorithm and Its Variations" }
  function LcsDistanceMyers(const L, R: rawbytestring): SizeInt;
  function LcsDistanceMyers(const L, R: array of Byte): SizeInt;
{ the same as above; the aLimit parameter indicates the maximum expected distance,
  if this value is exceeded when calculating the distance, then the function exits
  immediately and returns -1; aLimit < 0 means it is unknown }
  function LcsDistanceMyers(const L, R: rawbytestring; aLimit: SizeInt): SizeInt;
  function LcsDistanceMyers(const L, R: array of Byte; aLimit: SizeInt): SizeInt;
{ returns the Damerau-Levenshtein distance(restricted) between L and R using modified Berghel-Roach algorithm }
  function DumDistanceMbr(const L, R: rawbytestring): SizeInt;
  function DumDistanceMbr(const L, R: array of Byte): SizeInt;
{ the same as above; the aLimit parameter indicates the maximum expected distance,
  if this value is exceeded when calculating the distance, then the function exits
  immediately and returns -1; if aLimit < 0 it will be computed dynamically }
  function DumDistanceMbr(const L, R: rawbytestring; aLimit: SizeInt): SizeInt;
  function DumDistanceMbr(const L, R: array of Byte; aLimit: SizeInt): SizeInt;
{ returns similarity ratio using specified distance algorithm;
  aLimit specifies the lower bound of the required similarity(0.0 < aLimit <= 1.0),
  if the obtained value is less than the specified one, zero will be returned;
  aLimit <= 0 does not impose any restrictions on the obtained values }
  function SimRatio(const L, R: rawbytestring; aLimit: Double = Double(0); Algo: TSeqDistanceAlgo = sdaDefault): Double;
  function SimRatio(const L, R: array of Byte; aLimit: Double = Double(0); Algo: TSeqDistanceAlgo = sdaDefault): Double;

type
{ must convert the string to a single case, no matter which one }
  TSimCaseMap = function(const s: rawbytestring): rawbytestring;
  TSimLess    = function(const L, R: array of Char): Boolean;

const
  DEF_STOP_CHARS = [#0..#32];

{ returns the similarity ratio computed using the specified distance algorithm with some
  preprocessing of the input text; inspired by FuzzyWuzzy }
  function SimRatioEx(
    const L, R: rawbytestring;
    aMode: TSimMode = smSimple;
    const aStopChars: TSysCharSet = DEF_STOP_CHARS;
    const aOptions: TSimOptions = [];
    aLimit: Double = Double(0);
    Algo: TSeqDistanceAlgo = sdaDefault;
    aCaseMap: TSimCaseMap = nil;
    aLess: TSimLess = nil
  ): Double;
{ returns an array, each element of which contains the similarity ratio between
  aPattern and the corresponding element in the aValues array }
  function SimRatioList(
    const aPattern: rawbytestring;
    const aValues: array of rawbytestring;
    aMode: TSimMode = smSimple;
    const aStopChars: TSysCharSet = DEF_STOP_CHARS;
    const aOptions: TSimOptions = [];
    aLimit: Double = Double(0);
    Algo: TSeqDistanceAlgo = sdaDefault;
    aCaseMap: TSimCaseMap = nil;
    aLess: TSimLess = nil
  ): specialize TGArray<Double>;

type
  TRbStrRatio = record
    Value: rawbytestring;
    Ratio: Double;
  end;
{ returns an array of pairs sorted by descending similarity ratio and containing only those
  strings whose similarity ratio is not less than the specified boundary aLimit }
  function SelectSimilar(
    const aPattern: rawbytestring;
    const aValues: array of rawbytestring;
    aLimit: Double;
    aMode: TSimMode = smSimple;
    const aStopChars: TSysCharSet = DEF_STOP_CHARS;
    const aOptions: TSimOptions = [];
    Algo: TSeqDistanceAlgo = sdaDefault;
    aCaseMap: TSimCaseMap = nil;
    aLess: TSimLess = nil
  ): specialize TGArray<TRbStrRatio>;

  function IsValidDotQuadIPv4(const s: rawbytestring): Boolean;
  function IsValidDotDecIPv4(const s: rawbytestring): Boolean;

implementation
{$B-}{$COPERATORS ON}{$POINTERMATH ON}

function IsSubSequence(const aStr, aSub: rawbytestring): Boolean;
begin
  Result := specialize TGSimpleArrayHelper<Byte>.IsSubSequence(
    PByte(aStr)[0..Pred(System.Length(aStr))], PByte(aSub)[0..Pred(System.Length(aSub))]);
end;

function SkipPrefix(var pL, pR: PByte; var aLenL, aLenR: SizeInt): SizeInt; inline;
begin
  //implied aLenL <= aLenR
  Result := 0;

  while (Result < aLenL) and (pL[Result] = pR[Result]) do
    Inc(Result);

  pL += Result;
  pR += Result;
  aLenL -= Result;
  aLenR -= Result;
end;

function SkipSuffix(pL, pR: PByte; var aLenL, aLenR: SizeInt): SizeInt; inline;
begin
  //implied aLenL <= aLenR
  Result := 0;
  while (aLenL > 0) and (pL[Pred(aLenL)] = pR[Pred(aLenR)]) do
    begin
      Dec(aLenL);
      Dec(aLenR);
      Inc(Result);
    end;
end;

const
  MAX_STATIC = 1024;

{$PUSH}{$WARN 5057 OFF}
function LcsGusImpl(pL, pR: PByte; aLenL, aLenR: SizeInt): TBytes;
type
  TNode = record
    Index,
    Next: SizeInt;
  end;
  TNodeList = array of TNode;
var
  MatchList: array[Byte] of SizeInt;
  NodeList: TNodeList;
  Tmp: TSizeIntArray;
  LocLis: TSizeIntArray;
  I, J, PrefixLen, SuffixLen, NodeIdx: SizeInt;
const
  INIT_SIZE = 256; //???
begin
  //here aLenL <= aLenR
  Result := nil;

  if pL = pR then
    exit(specialize TGArrayHelpUtil<Byte>.CreateCopy(pL[0..Pred(aLenL)]));

  SuffixLen := SkipSuffix(pL, pR, aLenL, aLenR);
  PrefixLen := SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    begin
      System.SetLength(Result, PrefixLen + SuffixLen);
      System.Move((pL - PrefixLen)^, Pointer(Result)^, PrefixLen);
      System.Move((pL + aLenL)^, Result[PrefixLen], SuffixLen);
      exit;
    end;

  TSizeIntHelper.Fill(MatchList, NULL_INDEX);

  System.SetLength(NodeList, INIT_SIZE);
  J := 0;
  for I := 0 to Pred(aLenR) do
    begin
      if System.Length(NodeList) = J then
        System.SetLength(NodeList, J * 2);
      NodeList[J].Index := I;
      NodeList[J].Next := MatchList[pR[I]];
      MatchList[pR[I]] := J;
      Inc(J);
    end;

  System.SetLength(Tmp, INIT_SIZE);
  J := 0;
  for I := 0 to Pred(aLenL) do
    begin
      NodeIdx := MatchList[pL[I]];
      while NodeIdx <> NULL_INDEX do
        begin
          if System.Length(Tmp) = J then
            System.SetLength(Tmp, J * 2);
          Tmp[J] := NodeList[NodeIdx].Index;
          NodeIdx := NodeList[NodeIdx].Next;
          Inc(J);
        end;
    end;
  System.SetLength(Tmp, J);

  if Tmp <> nil then
    begin
      NodeList := nil;

      LocLis := TSizeIntHelper.Lis(Tmp);

      if LocLis = nil then
        begin
          System.SetLength(Result, Succ(PrefixLen + SuffixLen));
          Result[PrefixLen] := pR[Tmp[0]];
          System.Move((pL - PrefixLen)^, Pointer(Result)^, PrefixLen);
          System.Move((pL + aLenL)^, Result[Succ(PrefixLen)], SuffixLen);
        end
      else
        begin
          Tmp := nil;
          System.SetLength(Result, PrefixLen + System.Length(LocLis) + SuffixLen);
          for I := 0 to System.High(LocLis) do
            Result[I+PrefixLen] := pR[LocLis[I]];
          System.Move((pL - PrefixLen)^, Pointer(Result)^, PrefixLen);
          System.Move((pL + aLenL)^, Result[PrefixLen + System.Length(LocLis)], SuffixLen);
        end;
    end
  else
    begin
      System.SetLength(Result, PrefixLen + SuffixLen);
      if Result = nil then exit;
      System.Move((pL - PrefixLen)^, Pointer(Result)^, PrefixLen);
      System.Move((pL + aLenL)^, Result[PrefixLen], SuffixLen);
    end;
end;
{$POP}

function LcsGus(const L, R: rawbytestring): rawbytestring;
var
  b: TBytes;
begin
  Result := '';
  if (L = '') or (R = '') then
    exit;
  if System.Length(L) <= System.Length(R) then
    b := LcsGusImpl(Pointer(L), Pointer(R), System.Length(L), System.Length(R))
  else
    b := LcsGusImpl(Pointer(R), Pointer(L), System.Length(R), System.Length(L));
  System.SetLength(Result, System.Length(b));
  System.Move(Pointer(b)^, Pointer(Result)^, System.Length(b));
end;

function LcsGus(const L, R: array of Byte): TBytes;
begin
  if (System.Length(L) = 0) or (System.Length(R) = 0) then
    exit(nil);
  if System.Length(L) <= System.Length(R) then
    Result := LcsGusImpl(@L[0], @R[0], System.Length(L), System.Length(R))
  else
    Result := LcsGusImpl(@R[0], @L[0], System.Length(R), System.Length(L));
end;

{$PUSH}{$WARN 5089 OFF}
{
 S. Kiran Kumar and C. Pandu Rangan(1987) "A Linear Space Algorithm for the LCS Problem"
}
function LcsKrImpl(pL, pR: PByte; aLenL, aLenR: SizeInt): TBytes;
type
  TByteVector = specialize TGLiteVector<Byte>;
var
  LocLcs: TByteVector;
  R1, R2, LL, LL1, LL2: PSizeInt;
  R, S: SizeInt;
  procedure FillOne(LFirst, RFirst, RLast: SizeInt; DirectOrd: Boolean);
  var
    I, J, LoR, PosR, Tmp: SizeInt;
  begin
    J := 1;
    I := S;
    if DirectOrd then begin
      R2[0] := RLast - RFirst + 2;
      while I > 0 do begin
        if J > R then LoR := 0 else LoR := R1[J];
        PosR := R2[J - 1] - 1;
        while (PosR > LoR) and (pL[LFirst+(I-1)] <> pR[RFirst+(PosR-1)]) do
          Dec(PosR);
        Tmp := Math.Max(LoR, PosR);
        if Tmp = 0 then break;
        R2[J] := Tmp;
        Dec(I);
        Inc(J);
      end;
    end else begin
      R2[0] := RFirst - RLast + 2;
      while I > 0 do begin
        if J > R then LoR := 0 else LoR := R1[J];
        PosR := R2[J - 1] - 1;
        while (PosR > LoR) and (pL[LFirst-(I-1)] <> pR[RFirst-(PosR-1)]) do
          Dec(PosR);
        Tmp := Math.Max(LoR, PosR);
        if Tmp = 0 then break;
        R2[J] := Tmp;
        Dec(I);
        Inc(J);
      end;
    end;
    R := Pred(J);
  end;
  procedure Swap(var L, R: Pointer); inline;
  var
    Tmp: Pointer;
  begin
    Tmp := L;
    L := R;
    R := Tmp;
  end;
  procedure CalMid(LFirst, LLast, RFirst, RLast, Waste: SizeInt; L: PSizeInt; DirectOrd: Boolean);
  var
    P: SizeInt;
  begin
    if DirectOrd then
      S := Succ(LLast - LFirst)
    else
      S := Succ(LFirst - LLast);
    P := S - Waste;
    R := 0;
    while S >= P do begin
      FillOne(LFirst, RFirst, RLast, DirectOrd);
      Swap(R2, R1);
      Dec(S);
    end;
    System.Move(R1^, L^, Succ(R) * SizeOf(SizeInt));
  end;
  procedure SolveBaseCase(LFirst, LLast, RFirst, RLast, LcsLen: SizeInt);
  var
    I: SizeInt;
  begin
    CalMid(LFirst, LLast, RFirst, RLast, Succ(LLast - LFirst - LcsLen), LL, True);
    I := 0;
    while (I < LcsLen) and (pL[LFirst+I] = pR[RFirst+LL[LcsLen-I]-1]) do begin
      LocLcs.Add(pL[LFirst+I]);
      Inc(I);
    end;
    Inc(I);
    while I <= LLast - LFirst do begin
      LocLcs.Add(pL[LFirst+I]);
      Inc(I);
    end;
  end;
  procedure FindPerfectCut(LFirst, LLast, RFirst, RLast, LcsLen: SizeInt; out U, V: SizeInt);
  var
    I, LocR1, LocR2, K, W: SizeInt;
  begin
    W := Succ(LLast - LFirst - LcsLen) div 2;
    CalMid(LLast, LFirst, RLast, RFirst, W, LL1, False);
    LocR1 := R;
    for I := 0 to LocR1 do
      LL1[I] := RLast - RFirst - LL1[I] + 2;
    CalMid(LFirst, LLast, RFirst, RLast, W, LL2, True);
    LocR2 := R;
    K := Math.Max(LocR1, LocR2);
    while K > 0 do begin
      if (K <= LocR1) and (LcsLen - K <= LocR2) and (LL1[K] < LL2[LcsLen - K]) then break;
      Dec(K);
    end;
    U := K + W;
    V := LL1[K];
  end;
  procedure Lcs(LFirst, LLast, RFirst, RLast, LcsLen: SizeInt);
  var
    U, V, W: SizeInt;
  begin
    if (LLast < LFirst) or (RLast < RFirst) or (LcsLen < 1) then exit;
    if Succ(LLast - LFirst - LcsLen) < 2 then
      SolveBaseCase(LFirst, LLast, RFirst, RLast, LcsLen)
    else begin
      FindPerfectCut(LFirst, LLast, RFirst, RLast, LcsLen, U, V);
      W := Succ(LLast - LFirst - LcsLen) div 2;
      Lcs(LFirst, Pred(LFirst + U), RFirst, Pred(RFirst + V), U - W);
      Lcs(LFirst + U, LLast, RFirst + V, RLast, LcsLen + W - U);
    end;
  end;
  function GetLcsLen: SizeInt;
  begin
    R := 0;
    S := Succ(aLenL);
    while S > R do begin
      Dec(S);
      FillOne(0, 0, Pred(aLenR), True);
      Swap(R2, R1);
    end;
    Result := S;
  end;
var
  StBuf: array[0..Pred(MAX_STATIC)] of SizeInt;
  Buf: array of SizeInt;
  PrefixLen, SuffixLen: SizeInt;
begin
  //here aLenL <= aLenR
  Result := nil;

  if pL = pR then
    exit(specialize TGArrayHelpUtil<Byte>.CreateCopy(pL[0..Pred(aLenL)]));

  SuffixLen := SkipSuffix(pL, pR, aLenL, aLenR);
  PrefixLen := SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    begin
      System.SetLength(Result, PrefixLen + SuffixLen);
      System.Move((pL - PrefixLen)^, Pointer(Result)^, PrefixLen);
      System.Move((pL + aLenL)^, Result[PrefixLen], SuffixLen);
      exit;
    end;

  if MAX_STATIC >= Succ(aLenR)*5 then
    begin
      R1 := @StBuf[0];
      R2 := @StBuf[Succ(aLenR)];
      LL := @StBuf[Succ(aLenR)*2];
      LL1 := @StBuf[Succ(aLenR)*3];
      LL2 := @StBuf[Succ(aLenR)*4];
    end
  else
    begin
      System.SetLength(Buf, Succ(aLenR)*5);
      R1 := @Buf[0];
      R2 := @Buf[Succ(aLenR)];
      LL := @Buf[Succ(aLenR)*2];
      LL1 := @Buf[Succ(aLenR)*3];
      LL2 := @Buf[Succ(aLenR)*4];
    end;

  LocLcs.EnsureCapacity(aLenL);

  Lcs(0, Pred(aLenL), 0, Pred(aLenR), GetLcsLen());
  Buf := nil;

  System.SetLength(Result, PrefixLen + LocLcs.Count + SuffixLen);
  if Result = nil then exit;

  if LocLcs.NonEmpty then
    System.Move(LocLcs.UncMutable[0]^, Result[PrefixLen], LocLcs.Count);
  System.Move((pL - PrefixLen)^, Pointer(Result)^, PrefixLen);
  System.Move((pL + aLenL)^, Result[PrefixLen + LocLcs.Count], SuffixLen);
end;
{$POP}

function LcsKR(const L, R: rawbytestring): rawbytestring;
var
  b: TBytes;
begin
  Result := '';
  if (L = '') or (R = '') then
    exit;
  if System.Length(L) <= System.Length(R) then
    b := LcsKrImpl(Pointer(L), Pointer(R), System.Length(L), System.Length(R))
  else
    b := LcsKrImpl(Pointer(R), Pointer(L), System.Length(R), System.Length(L));
  System.SetLength(Result, System.Length(b));
  System.Move(Pointer(b)^, Pointer(Result)^, System.Length(b));
end;

function LcsKR(const L, R: array of Byte): TBytes;
begin
  if (System.Length(L) = 0) or (System.Length(R) = 0) then
    exit(nil);
  if System.Length(L) <= System.Length(R) then
    Result := LcsKrImpl(@L[0], @R[0], System.Length(L), System.Length(R))
  else
    Result := LcsKrImpl(@R[0], @L[0], System.Length(R), System.Length(L));
end;

type
  TSnake = record
    StartRow, StartCol,
    EndRow, EndCol: SizeInt;
    procedure SetStartCell(aRow, aCol: SizeInt); inline;
    procedure SetEndCell(aRow, aCol: SizeInt); inline;
  end;

procedure TSnake.SetStartCell(aRow, aCol: SizeInt);
begin
  StartRow := aRow;
  StartCol := aCol;
end;

procedure TSnake.SetEndCell(aRow, aCol: SizeInt);
begin
  EndRow := aRow;
  EndCol := aCol;
end;

{$PUSH}{$WARN 5089 OFF}{$WARN 5037 OFF}
{
  Eugene W. Myers(1986) "An O(ND) Difference Algorithm and Its Variations"
}
function LcsMyersImpl(pL, pR: PByte; aLenL, aLenR: SizeInt): TBytes;
type
  TByteVector = specialize TGLiteVector<Byte>;
var
  LocLcs: TByteVector;
  V0, V1: PSizeInt;
  function FindMiddleShake(LFirst, LLast, RFirst, RLast: SizeInt; out aSnake: TSnake): SizeInt;
  var
    LenL, LenR, Delta, Mid, D, K, Row, Col: SizeInt;
    ForV, RevV: PSizeInt;
    OddDelta: Boolean;
  begin
    LenL := Succ(LLast - LFirst);
    LenR := Succ(RLast - RFirst);
    Delta := LenL - LenR;
    OddDelta := Odd(Delta);
    Mid := (LenL + LenR) div 2 + Ord(OddDelta);
    ForV := @V0[Succ(Mid)];
    RevV := @V1[Succ(Mid)];
    ForV[1] := 0;
    RevV[1] := 0;
    for D := 0 to Mid do
      begin
        K := -D;
        while K <= D do
          begin
            if (K = -D) or ((K <> D) and (ForV[K - 1] < ForV[K + 1])) then
              Row := ForV[K + 1]
            else
              Row := ForV[K - 1] + 1;
            Col := Row - K;
            aSnake.SetStartCell(LFirst + Row, RFirst + Col);
            while (Row < LenL) and (Col < LenR) and (pL[LFirst + Row] = pR[RFirst + Col]) do
              begin
                Inc(Row);
                Inc(Col);
              end;
            ForV[K] := Row;
            if OddDelta and (K >= Delta - D + 1) and (K <= Delta + D - 1) and
               (Row + RevV[Delta - K] >= LenL) then
              begin
                aSnake.SetEndCell(LFirst + Row, RFirst + Col);
                exit(Pred(D * 2));
              end;
            K += 2;
          end;

        K := -D;
        while K <= D do
          begin
            if (K = -D) or ((K <> D) and (RevV[K - 1] < RevV[K + 1])) then
              Row := RevV[K + 1]
            else
              Row := RevV[K - 1] + 1;
            Col := Row - K;
            aSnake.SetEndCell(Succ(LLast - Row), Succ(RLast - Col));
            while (Row < LenL) and (Col < LenR) and (pL[LLast-Row] = pR[RLast-Col]) do
              begin
                Inc(Row);
                Inc(Col);
              end;
            RevV[K] := Row;
            if not OddDelta and (K <= D + Delta) and (K >= Delta - D) and
              (Row + ForV[Delta - K] >= LenL) then
              begin
                aSnake.SetStartCell(Succ(LLast - Row), Succ(RLast - Col));
                exit(D * 2);
              end;
            K += 2;
          end;
      end;
    raise Exception.Create('Internal error in ' + {$I %CURRENTROUTINE%});
    Result := NULL_INDEX;
  end;
  procedure Lcs(LFirst, LLast, RFirst, RLast: SizeInt);
  var
    Snake: TSnake;
    I: SizeInt;
  begin
    if (LLast < LFirst) or (RLast < RFirst) then exit;
    if FindMiddleShake(LFirst, LLast, RFirst, RLast, Snake) > 1 then
      begin
        Lcs(LFirst, Pred(Snake.StartRow), RFirst, Pred(Snake.StartCol));
        for I := Snake.StartRow to Pred(Snake.EndRow) do
          LocLcs.Add(pL[I]);
        Lcs(Snake.EndRow, LLast, Snake.EndCol, RLast);
      end
    else
      if LLast - LFirst < RLast - RFirst then
        for I := LFirst to LLast do
          LocLcs.Add(pL[I])
      else
        for I := RFirst to RLast do
          LocLcs.Add(pR[I]);
  end;
var
  StBuf: array[0..Pred(MAX_STATIC)] of SizeInt;
  Buf: array of SizeInt;
  PrefixLen, SuffixLen: SizeInt;
begin
  //here aLenL <= aLenR
  Result := nil;

  if pL = pR then
    exit(specialize TGArrayHelpUtil<Byte>.CreateCopy(pL[0..Pred(aLenL)]));

  SuffixLen := SkipSuffix(pL, pR, aLenL, aLenR);
  PrefixLen := SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    begin
      System.SetLength(Result, PrefixLen + SuffixLen);
      System.Move((pL - PrefixLen)^, Pointer(Result)^, PrefixLen);
      System.Move((pL + aLenL)^, Result[PrefixLen], SuffixLen);
      exit;
    end;

  if MAX_STATIC >= (aLenL+aLenR+2)*2 then
    begin
      V0 := @StBuf[0];
      V1 := @StBuf[(aLenL+aLenR+2)];
    end
  else
    begin
      System.SetLength(Buf, (aLenL+aLenR+2)*2);
      V0 := @Buf[0];
      V1 := @Buf[(aLenL+aLenR+2)];
    end;

  LocLcs.EnsureCapacity(aLenL);

  Lcs(0, Pred(aLenL), 0, Pred(aLenR));
  Buf := nil;

  System.SetLength(Result, PrefixLen + LocLcs.Count + SuffixLen);
  if Result = nil then exit;

  if LocLcs.NonEmpty then
    System.Move(LocLcs.UncMutable[0]^, Result[PrefixLen], LocLcs.Count);
  System.Move((pL - PrefixLen)^, Pointer(Result)^, PrefixLen);
  System.Move((pL + aLenL)^, Result[PrefixLen + LocLcs.Count], SuffixLen);
end;
{$POP}

function LcsMyers(const L, R: rawbytestring): rawbytestring;
var
  b: TBytes;
begin
  Result := '';
  if (L = '') or (R = '') then
    exit;
  if System.Length(L) <= System.Length(R) then
    b := LcsMyersImpl(Pointer(L), Pointer(R), System.Length(L), System.Length(R))
  else
    b := LcsMyersImpl(Pointer(R), Pointer(L), System.Length(R), System.Length(L));
  System.SetLength(Result, System.Length(b));
  System.Move(Pointer(b)^, Pointer(Result)^, System.Length(b));
end;

function LcsMyers(const L, R: array of Byte): TBytes;
begin
  if (System.Length(L) = 0) or (System.Length(R) = 0) then
    exit(nil);
  if System.Length(L) <= System.Length(R) then
    Result := LcsMyersImpl(@L[0], @R[0], System.Length(L), System.Length(R))
  else
    Result := LcsMyersImpl(@R[0], @L[0], System.Length(R), System.Length(L));
end;

function LevDistanceDpImpl(pL, pR: PByte; aLenL, aLenR: SizeInt): SizeInt;
var
  StBuf: array[0..Pred(MAX_STATIC)] of SizeInt;
  Buf: array of SizeInt = nil;
  I, J, Prev, Next: SizeInt;
  Dist: PSizeInt;
  b: Byte;
begin
  //here aLenL <= aLenR
  if pL = pR then
    exit(aLenR - aLenL);

  SkipSuffix(pL, pR, aLenL, aLenR);
  SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    exit(aLenR);


  if aLenR < MAX_STATIC then
    Dist := @StBuf[0]
  else
    begin
      System.SetLength(Buf, Succ(aLenR));
      Dist := Pointer(Buf);
    end;
  for I := 0 to aLenR do
    Dist[I] := I;

  for I := 1 to aLenL do
    begin
      Prev := I;
      b := pL[I-1];
      for J := 1 to aLenR do
        begin
          if pR[J-1] = b then
            Next := Dist[J-1]
          else
            Next := Succ(MinOf3(Dist[J-1], Prev, Dist[J]));
          Dist[J-1] := Prev;
          Prev := Next;
        end;
      Dist[aLenR] := Prev;
    end;
  Result := Dist[aLenR];
end;

function LevDistance(const L, R: rawbytestring): SizeInt;
begin
  if System.Length(L) = 0 then
    exit(System.Length(R))
  else
    if System.Length(R) = 0 then
      exit(System.Length(L));
  if System.Length(L) <= System.Length(R) then
    Result := LevDistanceDpImpl(Pointer(L), Pointer(R), System.Length(L), System.Length(R))
  else
    Result := LevDistanceDpImpl(Pointer(R), Pointer(L), System.Length(R), System.Length(L));
end;

function LevDistance(const L, R: array of Byte): SizeInt;
begin
  if System.Length(L) = 0 then
    exit(System.Length(R))
  else
    if System.Length(R) = 0 then
      exit(System.Length(L));
  if System.Length(L) <= System.Length(R) then
    Result := LevDistanceDpImpl(@L[0], @R[0], System.Length(L), System.Length(R))
  else
    Result := LevDistanceDpImpl(@R[0], @L[0], System.Length(R), System.Length(L));
end;

function LevDistanceMbrImpl(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;

  function FindRow(k, aDist, aLeft, aAbove, aRight: SizeInt): SizeInt; inline;
  var
    I, MaxRow: SizeInt;
  begin
    if aDist = 0 then
      I := 0
    else
      I := MaxOf3(aLeft, aAbove + 1, aRight + 1);
    MaxRow := Min(aLenL - k, aLenR);
    while (I < MaxRow) and (pR[I] = pL[I + k]) do
      Inc(I);
    FindRow := I;
  end;

var
  StBuf: array[0..Pred(MAX_STATIC)] of SizeInt;
  Buf: array of SizeInt = nil;

  CurrL, CurrR, LastL, LastR, PrevL, PrevR: PSizeInt;
  I, DMain, Dist, Diagonal, CurrRight, CurrLeft, Row: SizeInt;
  tmp: Pointer;
  Even: Boolean = True;
begin
  //here aLenL <= aLenR
  if aLimit > aLenR then
    aLimit := aLenR;

  DMain := aLenL - aLenR;
  Dist := -DMain;

  if aLimit < MAX_STATIC div 6 then
    begin
      CurrL := @StBuf[0];
      LastL := @StBuf[Succ(aLimit)];
      PrevL := @StBuf[Succ(aLimit)*2];
      CurrR := @StBuf[Succ(aLimit)*3];
      LastR := @StBuf[Succ(aLimit)*4];
      PrevR := @StBuf[Succ(aLimit)*5];
    end
  else
    begin
      System.SetLength(Buf, Succ(aLimit)*6);
      CurrL := Pointer(Buf);
      LastL := @Buf[Succ(aLimit)];
      PrevL := @Buf[Succ(aLimit)*2];
      CurrR := @Buf[Succ(aLimit)*3];
      LastR := @Buf[Succ(aLimit)*4];
      PrevR := @Buf[Succ(aLimit)*5];
    end;

  for I := 0 to Dist do
    begin
      LastR[I] := Dist - I - 1;
      PrevR[I] := NULL_INDEX;
    end;

  repeat

    Diagonal := (Dist - DMain) div 2;
    if Even then
      LastR[Diagonal] := NULL_INDEX;

    CurrRight := NULL_INDEX;

    while Diagonal > 0 do
      begin
        CurrRight :=
          FindRow( DMain + Diagonal, Dist - Diagonal, PrevR[Diagonal - 1], LastR[Diagonal], CurrRight);
        CurrR[Diagonal] := CurrRight;
        Dec(Diagonal);
      end;

    Diagonal := (Dist + DMain) div 2;

    if Even then
      begin
        LastL[Diagonal] := Pred((Dist - DMain) div 2);
        CurrLeft := NULL_INDEX;
      end
    else
      CurrLeft := (Dist - DMain) div 2;

    while Diagonal > 0 do
      begin
        CurrLeft :=
          FindRow(DMain - Diagonal, Dist - Diagonal, CurrLeft, LastL[Diagonal], PrevL[Diagonal - 1]);
        CurrL[Diagonal] := CurrLeft;
        Dec(Diagonal);
      end;

    Row := FindRow(DMain, Dist, CurrLeft, LastL[0], CurrRight);

    if Row = aLenR then
      break;

    Inc(Dist);
    if Dist > aLimit then
      exit(NULL_INDEX);

    CurrR[0] := Row;
    CurrL[0] := Row;

    tmp := PrevL;
    PrevL := LastL;
    LastL := CurrL;
    CurrL := tmp;

    tmp := PrevR;
    PrevR := LastR;
    LastR := CurrR;
    CurrR := tmp;

    Even := not Even;

  until False;

  Result := Dist;
end;

function LevDistanceMbrDyn(pL, pR: PByte; aLenL, aLenR: SizeInt): SizeInt;
var
  K: SizeInt;
begin
  //here aLenL <= aLenR
  if pL = pR then
    exit(aLenR - aLenL);

  SkipSuffix(pL, pR, aLenL, aLenR);
  SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    exit(aLenR);

  K := 0;
  repeat
    if K <> 0 then
      K := Math.Min(K * 2, aLenR)
    else
      K := Math.Max(aLenR - aLenL, 2); // 2 ???
    Result := LevDistanceMbrImpl(pL, pR, aLenL, aLenR, K);
  until Result <> NULL_INDEX;
end;

function GetLevDistanceMbr(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;
begin
  //here aLenL <= aLenR
  if aLimit < 0 then
    exit(LevDistanceMbrDyn(pL, pR, aLenL, aLenR));

  if aLenR - aLenL > aLimit then
    exit(NULL_INDEX);

  if pL = pR then
    exit(aLenR - aLenL);

  SkipSuffix(pL, pR, aLenL, aLenR);
  SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    exit(aLenR);

  if aLimit = 0 then  //////////
    exit(NULL_INDEX); //////////

  Result := LevDistanceMbrImpl(pL, pR, aLenL, aLenR, aLimit);
end;

function LevDistanceMbr(const L, R: rawbytestring): SizeInt;
begin
  if L = '' then
    exit(System.Length(R))
  else
    if R = '' then
      exit(System.Length(L));
  if System.Length(L) <= System.Length(R) then
    Result := GetLevDistanceMbr(Pointer(L), Pointer(R), System.Length(L), System.Length(R), System.Length(R))
  else
    Result := GetLevDistanceMbr(Pointer(R), Pointer(L), System.Length(R), System.Length(L), System.Length(L));
end;

function LevDistanceMbr(const L, R: array of Byte): SizeInt;
begin
  if System.Length(L) = 0 then
    exit(System.Length(R))
  else
    if System.Length(R) = 0 then
      exit(System.Length(L));
  if System.Length(L) <= System.Length(R) then
    Result := GetLevDistanceMbr(@L[0], @R[0], System.Length(L), System.Length(R), System.Length(R))
  else
    Result := GetLevDistanceMbr(@R[0], @L[0], System.Length(R), System.Length(L), System.Length(L));
end;

function LevDistanceMbr(const L, R: rawbytestring; aLimit: SizeInt): SizeInt;
begin
  if L = '' then
    if SizeUInt(System.Length(R)) <= SizeUInt(aLimit) then
      exit(System.Length(R))
    else
      exit(NULL_INDEX)
  else
    if R = '' then
      if SizeUInt(System.Length(L)) <= SizeUInt(aLimit) then
        exit(System.Length(L))
      else
        exit(NULL_INDEX);
  if System.Length(L) <= System.Length(R) then
    Result := GetLevDistanceMbr(Pointer(L), Pointer(R), System.Length(L), System.Length(R), aLimit)
  else
    Result := GetLevDistanceMbr(Pointer(R), Pointer(L), System.Length(R), System.Length(L), aLimit);
end;

function LevDistanceMbr(const L, R: array of Byte; aLimit: SizeInt): SizeInt;
begin
  if System.Length(L) = 0 then
    if SizeUInt(System.Length(R)) <= SizeUInt(aLimit) then
      exit(System.Length(R))
    else
      exit(NULL_INDEX)
  else
    if System.Length(R) = 0 then
      if SizeUInt(System.Length(L)) <= SizeUInt(aLimit) then
        exit(System.Length(L))
      else
        exit(NULL_INDEX);
  if System.Length(L) <= System.Length(R) then
    Result := GetLevDistanceMbr(@L[0], @R[0], System.Length(L), System.Length(R), aLimit)
  else
    Result := GetLevDistanceMbr(@R[0], @L[0], System.Length(R), System.Length(L), aLimit);
end;

{$PUSH}{$WARN 5057 OFF}{$WARN 5036 OFF}{$Q-}{$R-}
{
  Myers, G.(1999) "A fast bit-vector algorithm for approximate string matching based on dynamic programming"
  Heikki Hyyrö(2001) "Explaining and extending the bit-parallel approximate string matching algorithm of Myers"
  Martin Šošić, Mile Šikić(2017) "Edlib: a C/C++ library for fast, exact sequence alignment using edit distance"
  }
{ in terms of Hyyrö }
function LevDistMyersD(pL, pR: PByte; aLenL, aLenR: SizeInt): SizeInt;
var
  Pm: array[Byte] of DWord;
  PmI, Hp, Hn, Vp, Vn, D0: DWord;
  I: SizeInt;
begin
  System.FillChar(Pm, SizeOf(Pm), 0);
  for I := 0 to Pred(aLenL) do
    Pm[pL[I]] := Pm[pL[I]] or QWord(1) shl I;

  Result := aLenL;
  Vn := 0;
  Vp := High(DWord);

  for I := 0 to Pred(aLenR) do
    begin
      PmI := Pm[pR[I]];
      D0 := (((PmI and Vp) + Vp) xor Vp) or PmI or Vn;
      Hp := Vn or not(D0 or Vp);
      Hn := D0 and Vp;
      Vp := Hn shl 1 or not(D0 or Hp shl 1 or 1);
      Vn := D0 and (Hp shl 1 or 1);
      if Hn and (DWord(1) shl Pred(aLenL)) <> 0 then
        Dec(Result)
      else
        if Hp and (DWord(1) shl Pred(aLenL)) <> 0 then
          Inc(Result);
    end;
end;

function LevDistMyersD(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;
var
  Pm: array[Byte] of DWord;
  PmI, Hp, Hn, Vp, Vn, D0: DWord;
  I: SizeInt;
begin
  System.FillChar(Pm, SizeOf(Pm), 0);
  for I := 0 to Pred(aLenL) do
    Pm[pL[I]] := Pm[pL[I]] or QWord(1) shl I;

  Result := aLenL;
  aLimit += aLenR - aLenL;
  Vn := 0;
  Vp := High(DWord);

  for I := 0 to Pred(aLenR) do
    begin
      PmI := Pm[pR[I]];
      D0 := (((PmI and Vp) + Vp) xor Vp) or PmI or Vn;
      Hp := Vn or not(D0 or Vp);
      Hn := D0 and Vp;
      Vp := Hn shl 1 or not(D0 or Hp shl 1 or 1);
      Vn := D0 and (Hp shl 1 or 1);
      if Hn and (DWord(1) shl Pred(aLenL)) <> 0 then
        Dec(Result)
      else
        begin
          if Hp and (DWord(1) shl Pred(aLenL)) <> 0 then
            begin
              Inc(Result);
              aLimit -= 2;
            end
          else
            Dec(aLimit);
          if aLimit < 0 then
            exit(NULL_INDEX);
        end;
    end;
end;

function LevDistMyersQ(pL, pR: PByte; aLenL, aLenR: SizeInt): SizeInt;
var
  Pm: array[Byte] of QWord;
  PmI, Hp, Hv, Vp, Vn, D0: QWord;
  I: SizeInt;
begin
  System.FillChar(Pm, SizeOf(Pm), 0);
  for I := 0 to Pred(aLenL) do
    Pm[pL[I]] := Pm[pL[I]] or QWord(1) shl I;

  Result := aLenL;
  Vn := 0;
  Vp := High(QWord);

  for I := 0 to Pred(aLenR) do
    begin
      PmI := Pm[pR[I]];
      D0 := (((PmI and Vp) + Vp) xor Vp) or PmI or Vn;
      Hp := Vn or not(D0 or Vp);
      Hv := D0 and Vp;
      Vp := Hv shl 1 or not(D0 or Hp shl 1 or 1);
      Vn := D0 and (Hp shl 1 or 1);
      if Hv and (QWord(1) shl Pred(aLenL)) <> 0 then
        Dec(Result)
      else
        if Hp and (QWord(1) shl Pred(aLenL)) <> 0 then
          Inc(Result);
    end;
end;

function LevDistMyersQ(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;
var
  Pm: array[Byte] of QWord;
  PmI, Hp, Hn, Vp, Vn, D0: QWord;
  I: SizeInt;
begin
  System.FillChar(Pm, SizeOf(Pm), 0);
  for I := 0 to Pred(aLenL) do
    Pm[pL[I]] := Pm[pL[I]] or QWord(1) shl I;

  Result := aLenL;
  aLimit += aLenR - aLenL;
  Vn := 0;
  Vp := High(QWord);

  for I := 0 to Pred(aLenR) do
    begin
      PmI := Pm[pR[I]];
      D0 := (((PmI and Vp) + Vp) xor Vp) or PmI or Vn;
      Hp := Vn or not(D0 or Vp);
      Hn := D0 and Vp;
      Vp := Hn shl 1 or not(D0 or Hp shl 1 or 1);
      Vn := D0 and (Hp shl 1 or 1);
      if Hn and (QWord(1) shl Pred(aLenL)) <> 0 then
        Dec(Result)
      else
        begin
          if Hp and (QWord(1) shl Pred(aLenL)) <> 0 then
            begin
              Inc(Result);
              aLimit -= 2;
            end
          else
            Dec(aLimit);
          if aLimit < 0 then
            exit(NULL_INDEX);
        end;
    end;
end;

const
  BLOCK_SIZE = BitSizeOf(QWord);
  BSIZE_MASK = Pred(BLOCK_SIZE);
  BSIZE_LOG  = 6;

{ in terms of Myers }
function LevDistMyersDQ(pL, pR: PByte; aLenL, aLenR: SizeInt): SizeInt;
var
  Peq: array[Byte] of array[0..1] of QWord;
  Eq0, Eq1, Ph, Mh, Pv0, Mv0, Pv1, Mv1, Xv, Xh, Hin: QWord;
  I: SizeInt;
begin
  System.FillChar(Peq, SizeOf(Peq), 0);
  for I := 0 to Pred(BLOCK_SIZE) do
    Peq[pL[I]][0] := Peq[pL[I]][0] or QWord(1) shl I;
  for I := BLOCK_SIZE to Pred(aLenL) do
    Peq[pL[I]][1] := Peq[pL[I]][1] or QWord(1) shl (I - BLOCK_SIZE);

  Result := aLenL;
  Pv0 := High(QWord);
  Pv1 := High(QWord);
  Mv0 := 0;
  Mv1 := 0;

  for I := 0 to Pred(aLenR) do
    begin
      Eq0 := Peq[pR[I]][0];
      Eq1 := Peq[pR[I]][1];
      ///////////////////////
      Xv := Mv0 or Eq0;
      Xh := ((Pv0 and Eq0 + Pv0) xor Pv0) or Eq0;
      Ph := Mv0 or not(Xh or Pv0);
      Mh := Pv0 and Xh;
      Hin := Ph shr BSIZE_MASK - Mh shr BSIZE_MASK;
      Ph := Ph shl 1 or 1;
      Pv0 := Mh shl 1 or not(Xv or Ph);
      Mv0 := Xv and Ph;
      ///////////////////////
      Xv := Mv1 or Eq1;
      Eq1 := Eq1 or Hin shr BSIZE_MASK;
      Xh := ((Pv1 and Eq1 + Pv1) xor Pv1) or Eq1;
      Ph := Mv1 or not(Xh or Pv1);
      Mh := Pv1 and Xh;
      ///////////////////////
      if Mh and (QWord(1) shl Pred(aLenL - BLOCK_SIZE)) <> 0 then
        Dec(Result)
      else
        if Ph and (QWord(1) shl Pred(aLenL - BLOCK_SIZE)) <> 0 then
          Inc(Result);
      ///////////////////////
      Ph := Ph shl 1 or (Hin + 1) shr 1;
      Pv1 := (Mh shl 1 or Hin shr BSIZE_MASK) or not(Xv or Ph);
      Mv1 := Xv and Ph;
    end;
end;

function LevDistMyersDQ(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;
var
  Peq: array[Byte] of array[0..1] of QWord;
  Eq0, Eq1, Ph, Mh, Pv0, Mv0, Pv1, Mv1, Xv, Xh, Hin: QWord;
  I: SizeInt;
begin
  System.FillChar(Peq, SizeOf(Peq), 0);
  for I := 0 to Pred(BLOCK_SIZE) do
    Peq[pL[I]][0] := Peq[pL[I]][0] or QWord(1) shl I;
  for I := BLOCK_SIZE to Pred(aLenL) do
    Peq[pL[I]][1] := Peq[pL[I]][1] or QWord(1) shl (I - BLOCK_SIZE);

  Result := aLenL;
  aLimit += aLenR - aLenL;
  Pv0 := High(QWord);
  Pv1 := High(QWord);
  Mv0 := 0;
  Mv1 := 0;

  for I := 0 to Pred(aLenR) do
    begin
      Eq0 := Peq[pR[I]][0];
      Eq1 := Peq[pR[I]][1];
      ///////////////////////
      Xv := Mv0 or Eq0;
      Xh := ((Pv0 and Eq0 + Pv0) xor Pv0) or Eq0;
      Ph := Mv0 or not(Xh or Pv0);
      Mh := Pv0 and Xh;
      Hin := Ph shr BSIZE_MASK - Mh shr BSIZE_MASK;
      Ph := Ph shl 1 or 1;
      Pv0 := Mh shl 1 or not(Xv or Ph);
      Mv0 := Xv and Ph;
      ///////////////////////
      Xv := Mv1 or Eq1;
      Eq1 := Eq1 or Hin shr BSIZE_MASK;
      Xh := ((Pv1 and Eq1 + Pv1) xor Pv1) or Eq1;
      Ph := Mv1 or not(Xh or Pv1);
      Mh := Pv1 and Xh;
      ///////////////////////
      if Mh and (QWord(1) shl Pred(aLenL - BLOCK_SIZE)) <> 0 then
        Dec(Result)
      else
        begin
          if Ph and (QWord(1) shl Pred(aLenL - BLOCK_SIZE)) <> 0 then
            begin
              Inc(Result);
              aLimit -= 2;
            end
          else
            Dec(aLimit);
          if aLimit < 0 then
            exit(NULL_INDEX);
        end;
      ///////////////////////
      Ph := Ph shl 1 or (Hin + 1) shr 1;
      Pv1 := (Mh shl 1 or Hin shr BSIZE_MASK) or not(Xv or Ph);
      Mv1 := Xv and Ph;
    end;
end;

{ recodes sequences to determine alphabet size and minimize memory usage;
  returns the size of the new alphabet and recoded sequences in aBuffer }
function RecodeSeq(pL, pR: PByte; aLenL, aLenR: SizeInt; out aBuffer: TBytes): SizeInt;
var
  InTable: array[Byte] of Boolean;
  CodeTable: array[Byte] of Byte;
  I: SizeInt;
  b: Byte;
begin
  System.FillChar(InTable, SizeOf(InTable), 0);
  System.SetLength(aBuffer, aLenL + aLenR);
  Result := 0;
  for I := 0 to Pred(aLenL) do
    begin
      b := pL[I];
      if not InTable[b] then
        begin
          CodeTable[b] := Result;
          Inc(Result);
          InTable[b] := True;
        end;
      aBuffer[I] := CodeTable[b];
    end;
  for I := aLenL to Pred(aLenL + aLenR) do
    begin
      b := pR[I-aLenL];
      if not InTable[b] then
        begin
          CodeTable[b] := Result;
          Inc(Result);
          InTable[b] := True;
        end;
      aBuffer[I] := CodeTable[b];
    end;
end;

type
  TPeq = record
    Peq: array of PQWord;
    Buffer: array of QWord;
    BlockCount: SizeInt;
  end;

procedure CreatePeq(aSeq: PByte; aSeqLen, AlphabetSize: SizeInt; out aPeq: TPeq);
var
  I, J, BCount, LastRow: SizeInt;
  Pad: QWord;
begin
  LastRow := aSeqLen and BSIZE_MASK;
  BCount := aSeqLen shr BSIZE_LOG + Ord(LastRow <> 0);
  aPeq.BlockCount := BCount;
  System.SetLength(aPeq.Peq, AlphabetSize);

  System.SetLength(aPeq.Buffer, BCount * AlphabetSize);
  if LastRow <> 0 then
    Pad := System.High(QWord) shl LastRow
  else
    Pad := 0;
  J := 0;
  with aPeq do
    for I := 0 to Pred(AlphabetSize) do
      begin
        Peq[I] := @Buffer[J];
        Peq[I][Pred(BCount)] := Pad; ////////////???
        J += BCount;
      end;
  with aPeq do
    for I := 0 to Pred(aSeqLen) do
      Peq[aSeq[I]][I shr BSIZE_LOG] := Peq[aSeq[I]][I shr BSIZE_LOG] or QWord(1) shl (I and BSIZE_MASK);
end;

type
  TBlock = record
    P,
    M: QWord;
    Score: SizeInt;
  end;

{
  with some imrovements from Martin Šošić, Mile Šikić:
    "Edlib: a C/C 11 library for fast, exact sequence alignment using edit distance"
}
function LevDistMyersCutoff(const aPeq: TPeq; pR: PByte; aLenL, aLenR, K: SizeInt): SizeInt;
  function ReadBlockCell(const aBlock: TBlock; aIndex: SizeInt): SizeInt;
  var
    I: SizeInt;
  begin
    Result := aBlock.Score;
    for I := BSIZE_MASK downto Succ(aIndex) do
      if aBlock.P and (QWord(1) shl I) <> 0 then
        Dec(Result)
      else
        if aBlock.M and (QWord(1) shl I) <> 0 then
          Inc(Result);
  end;
var
  Blocks: array of TBlock;
  Eq, Xv, Xh, Pv, Mv, Ph, Mh, HIn, HOut: QWord;
  I, J, First, Last: SizeInt;
begin
  //here aLenL <= aLenR and K >= aLenR - aLenL
  K := Math.Min(k, aLenR);
  First := 0;
  I := Succ(Math.Min(K, (K - aLenR + aLenL) div 2));
  Last := Pred(Math.Min(aPeq.BlockCount, I shr BSIZE_LOG + Ord(I and BSIZE_MASK <> 0)));
  System.SetLength(Blocks, aPeq.BlockCount);
  Result := NULL_INDEX;

  for I := First to Last do
    with Blocks[I] do
      begin
        P := System.High(QWord);
        Score := BLOCK_SIZE * Succ(I);
      end;

  for I := 0 to Pred(aLenR) do
    begin
      HOut := 1;
      for J := First to Last do
        begin
          HIn := HOut;
          Eq := aPeq.Peq[pR[I]][J];
          Pv := Blocks[J].P;
          Mv := Blocks[J].M;
          Xv := Mv or Eq;
          Eq := Eq or HIn shr BSIZE_MASK;
          Xh := ((Pv and Eq + Pv) xor Pv) or Eq;
          Ph := Mv or not(Xh or Pv);
          Mh := Pv and Xh;

          HOut := Ph shr BSIZE_MASK - Mh shr BSIZE_MASK;

          Ph := Ph shl 1 or (HIn + 1) shr 1;

          Blocks[J].P := (Mh shl 1 or HIn shr BSIZE_MASK) or not(Xv or Ph);
          Blocks[J].M := Xv and Ph;
          Blocks[J].Score += SizeInt(HOut);
        end;
      // adjust last block
      if (Last < Pred(aPeq.BlockCount)) and
         (K-Blocks[Last].Score+BSIZE_MASK-aLenR+aLenL+I >= Last*BLOCK_SIZE) then
        begin
          Inc(Last);
          HIn := HOut;
          Eq := aPeq.Peq[pR[I]][Last];
          Pv := System.High(QWord);
          Mv := 0;
          Xv := Mv or Eq;
          Eq := Eq or HIn shr BSIZE_MASK;
          Xh := ((Pv and Eq + Pv) xor Pv) or Eq;
          Ph := Mv or not(Xh or Pv);
          Mh := Pv and Xh;

          HOut := Ph shr BSIZE_MASK - Mh shr BSIZE_MASK;

          Ph := Ph shl 1 or (HIn + 1) shr 1;

          Blocks[Last].P := (Mh shl 1 or HIn shr BSIZE_MASK) or not(Xv or Ph);
          Blocks[Last].M := Xv and Ph;
          Blocks[Last].Score := Blocks[Last-1].Score - SizeInt(HIn) + BLOCK_SIZE + SizeInt(HOut);
        end
      else
        while (Last >= First) and ((Blocks[Last].Score >= K + BLOCK_SIZE) or
              (K-Blocks[Last].Score+BSIZE_MASK-aLenR+aLenL+I+1 < Last*BLOCK_SIZE)) do
          Dec(Last);
      // adjust first block
      while (First <= Last) and ((Blocks[First].Score >= K + BLOCK_SIZE) or
            (Blocks[First].Score-K-aLenR+aLenL+I > (First+1)*BLOCK_SIZE-1)) do
        Inc(First);

      if Last < First then exit;
    end;

  if Last = Pred(aPeq.BlockCount) then
    begin
      I := Pred(aLenL and BSIZE_MASK);
      if I < 0 then I += BLOCK_SIZE;
      J := ReadBlockCell(Blocks[Last], I);
      if J <= K then
        Result := J;
    end;
end;
{$POP}

function LevDistMyersDyn(pL, pR: PByte; aLenL, aLenR: SizeInt): SizeInt;
var
  Peq: TPeq;
  Buffer: TBytes;
  AlphabetSize, Limit: SizeInt;
begin
  //here aLenL <= aLenR
  AlphabetSize := RecodeSeq(pL, pR, aLenL, aLenR, Buffer);
  CreatePeq(Pointer(Buffer), aLenL, AlphabetSize, Peq);
  Limit := Math.Max(BLOCK_SIZE, aLenR - aLenL);
  repeat
    Result := LevDistMyersCutoff(Peq, @Buffer[aLenL], aLenL, aLenR, Limit);
    Limit += Limit;
  until Result <> NULL_INDEX;
end;

function LevDistMyers(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;
var
  Peq: TPeq;
  Buffer: TBytes;
  AlphabetSize: SizeInt;
begin
  AlphabetSize := RecodeSeq(pL, pR, aLenL, aLenR, Buffer);
  CreatePeq(Pointer(Buffer), aLenL, AlphabetSize, Peq);
  Result := LevDistMyersCutoff(Peq, @Buffer[aLenL], aLenL, aLenR, aLimit);
end;

function GetLevDistMyers(pL, pR: PByte; aLenL, aLenR: SizeInt): SizeInt;
begin
  //here aLenL <= aLenR
  if pL = pR then
    exit(aLenR - aLenL);

  SkipSuffix(pL, pR, aLenL, aLenR);
  SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    exit(aLenR);

  case aLenL of
    1..BitSizeOf(DWord):
      Result := LevDistMyersD(pL, pR, aLenL, aLenR);
    BitSizeOf(DWord)+1..BitSizeOf(QWord):
      Result := LevDistMyersQ(pL, pR, aLenL, aLenR);
    BitSizeOf(QWord)+1..BitSizeOf(QWord)*2:
      Result := LevDistMyersDQ(pL, pR, aLenL, aLenR);
  else
    Result := LevDistMyersDyn(pL, pR, aLenL, aLenR);
  end;
end;

function LevDistanceMyers(const L, R: rawbytestring): SizeInt;
begin
  if L = '' then
    exit(System.Length(R))
  else
    if R = '' then
      exit(System.Length(L));
  if System.Length(L) <= System.Length(R) then
    Result := GetLevDistMyers(Pointer(L), Pointer(R), System.Length(L), System.Length(R))
  else
    Result := GetLevDistMyers(Pointer(R), Pointer(L), System.Length(R), System.Length(L));
end;

function LevDistanceMyers(const L, R: array of Byte): SizeInt;
begin
  if System.Length(L) = 0 then
    exit(System.Length(R))
  else
    if System.Length(R) = 0 then
      exit(System.Length(L));
  if System.Length(L) <= System.Length(R) then
    Result := GetLevDistMyers(@L[0], @R[0], System.Length(L), System.Length(R))
  else
    Result := GetLevDistMyers(@R[0], @L[0], System.Length(R), System.Length(L));
end;

function GetLevDistMyers(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;
begin
  //here aLenL <= aLenR
  if aLimit < 0 then
    exit(GetLevDistMyers(pL, pR, aLenL, aLenR));

  if aLenR - aLenL > aLimit then
    exit(NULL_INDEX);

  if pL = pR then
    exit(aLenR - aLenL);

  SkipSuffix(pL, pR, aLenL, aLenR);
  SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    exit(aLenR);

  if aLimit = 0 then  //////////
    exit(NULL_INDEX); //////////

  if aLimit > aLenR then
    aLimit := aLenR;

  case aLenL of
    1..BitSizeOf(DWord):
      Result := LevDistMyersD(pL, pR, aLenL, aLenR, aLimit);
    BitSizeOf(DWord)+1..BitSizeOf(QWord):
      Result := LevDistMyersQ(pL, pR, aLenL, aLenR, aLimit);
    BitSizeOf(QWord)+1..BitSizeOf(QWord)*2:
      Result := LevDistMyersDQ(pL, pR, aLenL, aLenR, aLimit);
  else
    Result := LevDistMyers(pL, pR, aLenL, aLenR, aLimit);
  end;
end;

function LevDistanceMyers(const L, R: rawbytestring; aLimit: SizeInt): SizeInt;
begin
  if L = '' then
    if System.Length(R) <= aLimit then
      exit(System.Length(R))
    else
      exit(NULL_INDEX)
  else
    if R = '' then
      if System.Length(L) <= aLimit then
        exit(System.Length(L))
      else
        exit(NULL_INDEX);
  if System.Length(L) <= System.Length(R) then
    Result := GetLevDistMyers(Pointer(L), Pointer(R), System.Length(L), System.Length(R), aLimit)
  else
    Result := GetLevDistMyers(Pointer(R), Pointer(L), System.Length(R), System.Length(L), aLimit);
end;

function LevDistanceMyers(const L, R: array of Byte; aLimit: SizeInt): SizeInt;
begin
  if System.Length(L) = 0 then
    if System.Length(R) <= aLimit then
      exit(System.Length(R))
    else
      exit(NULL_INDEX)
  else
    if System.Length(R) = 0 then
      if System.Length(L) <= aLimit then
        exit(System.Length(L))
      else
        exit(NULL_INDEX);
  if System.Length(L) <= System.Length(R) then
    Result := GetLevDistMyers(@L[0], @R[0], System.Length(L), System.Length(R), aLimit)
  else
    Result := GetLevDistMyers(@R[0], @L[0], System.Length(R), System.Length(L), aLimit);
end;

{$PUSH}{$WARN 5057 OFF}
function LcsDistMyersImpl(pL, pR: PByte; M{lenL}, N{lenR}: SizeInt): SizeInt;
var
  I, J, D, K, HiK: SizeInt;
  V: PSizeInt;
  StBuf: array[0..Pred(MAX_STATIC)] of SizeInt;
  Buf: array of SizeInt = nil;
begin

  if M + N < Pred(MAX_STATIC) then
    begin
      System.FillChar(StBuf, (M + N + 2) * SizeOf(SizeInt), 0);
      V := @StBuf[Succ(M)];
    end
  else
    begin
      System.SetLength(Buf, M + N + 2);
      V := @Buf[Succ(M)];
    end;

  for D := 0 to M + N do
    begin
      K := -(D - 2 * Math.Max(0, D - M));
      HiK := D - 2 * Math.Max(0, D - N);
      while K <= HiK do
        begin
          if (K = -D) or ((K <> D) and (V[K - 1] < V[K + 1])) then
            J := V[K + 1]
          else
            J := V[K - 1] + 1;
          I := J - K;
          while (J < N) and (I < M) and (pL[I] = pR[J]) do
            begin
              Inc(J);
              Inc(I);
            end;
          if (I = M) and (J = N) then exit(D);
          V[K] := J;
          K += 2;
        end;
    end;

  Result := NULL_INDEX; //we should never come here
end;
{$POP}

function LcsDistanceMyers(const L, R: rawbytestring): SizeInt;
var
  pL: PByte absolute L;
  pR: PByte absolute R;
  M, N: SizeInt;
begin
  M := System.Length(L);
  N := System.Length(R);
  if M = 0 then
    exit(N)
  else
    if N = 0 then
      exit(M);
  Result := LcsDistMyersImpl(pL, pR, M, N);
end;

function LcsDistanceMyers(const L, R: array of Byte): SizeInt;
var
  M, N: SizeInt;
begin
  M := System.Length(L);
  N := System.Length(R);
  if M = 0 then
    exit(N)
  else
    if N = 0 then
      exit(M);
  Result := LcsDistMyersImpl(@L[0], @R[0], M, N);
end;

{$PUSH}{$WARN 5057 OFF}
function LcsDistMyersImplLim(pL, pR: PByte; M{lenL}, N{lenR}, aLimit: SizeInt): SizeInt;
var
  I, J, D, K, HiK: SizeInt;
  V: PSizeInt;
  StBuf: array[0..Pred(MAX_STATIC)] of SizeInt;
  Buf: array of SizeInt = nil;
begin

  if M + N < Pred(MAX_STATIC) then
    begin
      System.FillChar(StBuf, (M + N + 2) * SizeOf(SizeInt), 0);
      V := @StBuf[Succ(M)];
    end
  else
    begin
      System.SetLength(Buf, M + N + 2);
      V := @Buf[Succ(M)];
    end;

  for D := 0 to M + N do
    begin
      K := -(D - 2 * Math.Max(0, D - M));
      HiK := D - 2 * Math.Max(0, D - N);
      while K <= HiK do
        begin
          if (K = -D) or ((K <> D) and (V[K - 1] < V[K + 1])) then
            J := V[K + 1]
          else
            J := V[K - 1] + 1;
          I := J - K;
          while (J < N) and (I < M) and (pL[I] = pR[J]) do
            begin
              Inc(J);
              Inc(I);
            end;
          if (I = M) and (J = N) then exit(D);
          V[K] := J;
          K += 2;
        end;
      if D = aLimit then break;
    end;

  Result := NULL_INDEX;
end;
{$POP}

function LcsDistanceMyers(const L, R: rawbytestring; aLimit: SizeInt): SizeInt;
var
  pL: PByte absolute L;
  pR: PByte absolute R;
  M, N: SizeInt;
begin
  if aLimit < 0 then
    aLimit := System.Length(L) + System.Length(R)
  else
    if aLimit = 0 then
      begin
        if L = R then exit(0);
        exit(NULL_INDEX);
      end;
  M := System.Length(L);
  N := System.Length(R);
  if M = 0 then
    if N > aLimit then
      exit(NULL_INDEX)
    else
      exit(N)
  else
    if N = 0 then
      if M > aLimit then
        exit(NULL_INDEX)
      else
        exit(M);
  Result := LcsDistMyersImplLim(pL, pR, M, N, aLimit);
end;

function LcsDistanceMyers(const L, R: array of Byte; aLimit: SizeInt): SizeInt;
var
  M, N: SizeInt;
begin
  if aLimit < 0 then aLimit := System.Length(L) + System.Length(R);
  M := System.Length(L);  N := System.Length(R);
  if (aLimit = 0) and (M <> N) then exit(NULL_INDEX);
  if M = 0 then
    if N > aLimit then
      exit(NULL_INDEX)
    else
      exit(N)
  else
    if N = 0 then
      if M > aLimit then
        exit(NULL_INDEX)
      else
        exit(M);
  Result := LcsDistMyersImplLim(@L[0], @R[0], M, N, aLimit);
end;

function DumDistanceMbrImpl(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;

  function FindRow(k, aDist, aLeft, aAbove, aRight: SizeInt): SizeInt; inline;
  var
    I, MaxRow: SizeInt;
  begin
    if aDist = 0 then
      I := 0
    else
      I := MaxOf3(aLeft,aAbove+Ord((pR[aAbove+1]=pL[aAbove+k])and(pR[aAbove]=pL[aAbove+k+1]))+1,aRight+1);
    MaxRow := Min(aLenL - k, aLenR);
    while (I < MaxRow) and (pR[I] = pL[I + k]) do
      Inc(I);
    FindRow := I;
  end;

var
  StBuf: array[0..Pred(MAX_STATIC)] of SizeInt;
  Buf: array of SizeInt = nil;

  CurrL, CurrR, LastL, LastR, PrevL, PrevR: PSizeInt;
  I, DMain, Dist, Diagonal, CurrRight, CurrLeft, Row: SizeInt;
  tmp: Pointer;
  Even: Boolean = True;
begin
  //here aLenL <= aLenR
  if aLimit > aLenR then
    aLimit := aLenR;

  DMain := aLenL - aLenR;
  Dist := -DMain;

  if aLimit < MAX_STATIC div 6 then
    begin
      CurrL := @StBuf[0];
      LastL := @StBuf[Succ(aLimit)];
      PrevL := @StBuf[Succ(aLimit)*2];
      CurrR := @StBuf[Succ(aLimit)*3];
      LastR := @StBuf[Succ(aLimit)*4];
      PrevR := @StBuf[Succ(aLimit)*5];
    end
  else
    begin
      System.SetLength(Buf, Succ(aLimit)*6);
      CurrL := Pointer(Buf);
      LastL := @Buf[Succ(aLimit)];
      PrevL := @Buf[Succ(aLimit)*2];
      CurrR := @Buf[Succ(aLimit)*3];
      LastR := @Buf[Succ(aLimit)*4];
      PrevR := @Buf[Succ(aLimit)*5];
    end;

  for I := 0 to Dist do
    begin
      LastR[I] := Dist - I - 1;
      PrevR[I] := NULL_INDEX;
    end;

  repeat

    Diagonal := (Dist - DMain) div 2;
    if Even then
      LastR[Diagonal] := NULL_INDEX;

    CurrRight := NULL_INDEX;

    while Diagonal > 0 do
      begin
        CurrRight :=
          FindRow( DMain + Diagonal, Dist - Diagonal, PrevR[Diagonal - 1], LastR[Diagonal], CurrRight);
        CurrR[Diagonal] := CurrRight;
        Dec(Diagonal);
      end;

    Diagonal := (Dist + DMain) div 2;

    if Even then
      begin
        LastL[Diagonal] := Pred((Dist - DMain) div 2);
        CurrLeft := NULL_INDEX;
      end
    else
      CurrLeft := (Dist - DMain) div 2;

    while Diagonal > 0 do
      begin
        CurrLeft :=
          FindRow(DMain - Diagonal, Dist - Diagonal, CurrLeft, LastL[Diagonal], PrevL[Diagonal - 1]);
        CurrL[Diagonal] := CurrLeft;
        Dec(Diagonal);
      end;

    Row := FindRow(DMain, Dist, CurrLeft, LastL[0], CurrRight);

    if Row = aLenR then
      break;

    Inc(Dist);
    if Dist > aLimit then
      exit(NULL_INDEX);

    CurrR[0] := Row;
    CurrL[0] := Row;

    tmp := PrevL;
    PrevL := LastL;
    LastL := CurrL;
    CurrL := tmp;

    tmp := PrevR;
    PrevR := LastR;
    LastR := CurrR;
    CurrR := tmp;

    Even := not Even;

  until False;

  Result := Dist;
end;

function DumDistanceMbrDyn(pL, pR: PByte; aLenL, aLenR: SizeInt): SizeInt;
var
  K: SizeInt;
begin
  //here aLenL <= aLenR
  if pL = pR then
    exit(aLenR - aLenL);

  SkipSuffix(pL, pR, aLenL, aLenR);
  SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    exit(aLenR);

  K := 0;
  repeat
    if K <> 0 then
      K := Math.Min(K * 2, aLenR)
    else
      K := Math.Max(aLenR - aLenL, 2); // 2 ???
    Result := DumDistanceMbrImpl(pL, pR, aLenL, aLenR, K);
  until Result <> NULL_INDEX;
end;

function GetDumDistanceMbr(pL, pR: PByte; aLenL, aLenR, aLimit: SizeInt): SizeInt;
begin
  //here aLenL <= aLenR
  if aLimit < 0 then
    exit(DumDistanceMbrDyn(pL, pR, aLenL, aLenR));

  if aLenR - aLenL > aLimit then
    exit(NULL_INDEX);

  if pL = pR then
    exit(aLenR - aLenL);

  SkipSuffix(pL, pR, aLenL, aLenR);
  SkipPrefix(pL, pR, aLenL, aLenR);

  if aLenL = 0 then
    exit(aLenR);

  if aLimit = 0 then  //////////
    exit(NULL_INDEX); //////////

  Result := DumDistanceMbrImpl(pL, pR, aLenL, aLenR, aLimit);
end;

function DumDistanceMbr(const L, R: rawbytestring): SizeInt;
begin
  if L = '' then
    exit(System.Length(R))
  else
    if R = '' then
      exit(System.Length(L));
  if System.Length(L) <= System.Length(R) then
    Result := GetDumDistanceMbr(Pointer(L), Pointer(R), System.Length(L), System.Length(R), System.Length(R))
  else
    Result := GetDumDistanceMbr(Pointer(R), Pointer(L), System.Length(R), System.Length(L), System.Length(L));
end;

function DumDistanceMbr(const L, R: array of Byte): SizeInt;
begin
  if System.Length(L) = 0 then
    exit(System.Length(R))
  else
    if System.Length(R) = 0 then
      exit(System.Length(L));
  if System.Length(L) <= System.Length(R) then
    Result := GetDumDistanceMbr(@L[0], @R[0], System.Length(L), System.Length(R), System.Length(R))
  else
    Result := GetDumDistanceMbr(@R[0], @L[0], System.Length(R), System.Length(L), System.Length(L));
end;

function DumDistanceMbr(const L, R: rawbytestring; aLimit: SizeInt): SizeInt;
begin
  if L = '' then
    if SizeUInt(System.Length(R)) <= SizeUInt(aLimit) then
      exit(System.Length(R))
    else
      exit(NULL_INDEX)
  else
    if R = '' then
      if SizeUInt(System.Length(L)) <= SizeUInt(aLimit) then
        exit(System.Length(L))
      else
        exit(NULL_INDEX);
  if System.Length(L) <= System.Length(R) then
    Result := GetDumDistanceMbr(Pointer(L), Pointer(R), System.Length(L), System.Length(R), aLimit)
  else
    Result := GetDumDistanceMbr(Pointer(R), Pointer(L), System.Length(R), System.Length(L), aLimit);
end;

function DumDistanceMbr(const L, R: array of Byte; aLimit: SizeInt): SizeInt;
begin
  if System.Length(L) = 0 then
    if SizeUInt(System.Length(R)) <= SizeUInt(aLimit) then
      exit(System.Length(R))
    else
      exit(NULL_INDEX)
  else
    if System.Length(R) = 0 then
      if SizeUInt(System.Length(L)) <= SizeUInt(aLimit) then
        exit(System.Length(L))
      else
        exit(NULL_INDEX);
  if System.Length(L) <= System.Length(R) then
    Result := GetDumDistanceMbr(@L[0], @R[0], System.Length(L), System.Length(R), aLimit)
  else
    Result := GetDumDistanceMbr(@R[0], @L[0], System.Length(R), System.Length(L), aLimit);
end;

function SimRatio(const L, R: rawbytestring; aLimit: Double; Algo: TSeqDistanceAlgo): Double;
var
  Len, Limit, Dist: SizeInt;
begin
  if (L = '') and (R = '') then exit(Double(1.0));
  if aLimit < 0 then aLimit := Double(0);
  if aLimit > 1 then aLimit := Double(1);
  if Algo = sdaLcsMyers then
    Len := System.Length(L) + System.Length(R)
  else
    Len := Math.Max(System.Length(L), System.Length(R));
  if aLimit = Double(0) then begin
    case Algo of
      sdaDefault,
      sdaLevMyers: Dist := LevDistanceMyers(L, R);
      sdaLevMBR:   Dist := LevDistanceMbr(L, R);
      sdaLcsMyers: Dist := LcsDistanceMyers(L, R);
    else // sdaDumMBR
      Dist := DumDistanceMbr(L, R);
    end;
    exit(Double(Len - Dist)/Double(Len));
  end;
  if aLimit > 0 then
    Limit := Len - {$IFDEF CPU64}Ceil64{$ELSE}Ceil{$ENDIF}(aLimit*Len)
  else
    Limit := -1;
  case Algo of
    sdaDefault:
      if aLimit > Double(0.90) then  //todo: more precise ???
        Dist := LevDistanceMbr(L, R, Limit)
      else
        Dist := LevDistanceMyers(L, R, Limit);
    sdaLevMBR:   Dist := LevDistanceMbr(L, R, Limit);
    sdaLevMyers: Dist := LevDistanceMyers(L, R, Limit);
    sdaLcsMyers: Dist := LcsDistanceMyers(L, R, Limit);
  else // sdaDumMBR
    Dist := DumDistanceMbr(L, R, Limit);
  end;
  if Dist <> NULL_INDEX then
    Result := Double(Len - Dist)/Double(Len)
  else
    Result := Double(0);
end;

function SimRatio(const L, R: array of Byte; aLimit: Double; Algo: TSeqDistanceAlgo): Double;
var
  Len, Limit, Dist: SizeInt;
begin
  if (System.Length(L) = 0) and (System.Length(R) = 0) then exit(Double(1.0));
  if aLimit < 0 then aLimit := Double(0);
  if aLimit > 1 then aLimit := Double(1);
  if Algo = sdaLcsMyers then
    Len := System.Length(L) + System.Length(R)
  else
    Len := Math.Max(System.Length(L), System.Length(R));
  if aLimit = Double(0) then begin
    case Algo of
      sdaDefault,
      sdaLevMyers: Dist := LevDistanceMyers(L, R);
      sdaLevMBR:   Dist := LevDistanceMbr(L, R);
      sdaLcsMyers: Dist := LcsDistanceMyers(L, R);
    else // sdaDumMBR
      Dist := DumDistanceMbr(L, R);
    end;
    exit(Double(Len - Dist)/Double(Len));
  end;
  if aLimit > 0 then
    Limit := Len - {$IFDEF CPU64}Ceil64{$ELSE}Ceil{$ENDIF}(aLimit*Len)
  else
    Limit := -1;
  case Algo of
    sdaDefault:
      if aLimit > Double(0.90) then //todo: more precise ???
        Dist := LevDistanceMbr(L, R, Limit)
      else
        Dist := LevDistanceMyers(L, R, Limit);
    sdaLevMBR:   Dist := LevDistanceMbr(L, R, Limit);
    sdaLevMyers: Dist := LevDistanceMyers(L, R, Limit);
    sdaLcsMyers: Dist := LcsDistanceMyers(L, R, Limit);
  else // sdaDumMBR
    Dist := DumDistanceMbr(L, R, Limit);
  end;
  if Dist <> NULL_INDEX then
    Result := Double(Len - Dist)/Double(Len)
  else
    Result := Double(0);
end;

{$PUSH}{$WARN 5089 OFF}
function SimRatioEx(const L, R: rawbytestring; aMode: TSimMode; const aStopChars: TSysCharSet;
  const aOptions: TSimOptions; aLimit: Double; Algo: TSeqDistanceAlgo; aCaseMap: TSimCaseMap;
  aLess: TSimLess): Double;
type
  TWord      = record Start: PChar; Len: SizeInt end;
  PWord      = ^TWord;
  TWordArray = array of TWord;
  TSplitFun  = function(const s: rawbytestring; out aCount: SizeInt; out aBuf: TWordArray;
                        aForceDyn: Boolean): PWord is nested;
  THelper    = specialize TGNestedArrayHelper<TWord>;
var
  StBuf: array[0..Pred(MAX_STATIC)] of TWord;

  function SplitMerge(const s: rawbytestring): rawbytestring;
  var
    I, J: SizeInt;
    pS, pR: PChar;
    NewWord: Boolean;
  begin
    if aStopChars = [] then exit(s);
    System.SetLength(Result, System.Length(s));
    pS := Pointer(s);
    pR := Pointer(Result);
    I := 0;
    while (I < System.Length(s)) and (pS[I] in aStopChars) do Inc(I);
    J := 0;
    NewWord := False;
    for I := I to Pred(System.Length(s)) do
      if pS[I] in aStopChars then
        NewWord := True
      else begin
        if NewWord then begin
          pR[J] := ' ';
          Inc(J);
          NewWord := False;
        end;
        pR[J] := pS[I];
        Inc(J);
      end;
    System.SetLength(Result, J);
  end;

  function Less(const L, R: TWord): Boolean; inline;
  begin
    Result := aLess(L.Start[0..Pred(L.Len)], R.Start[0..Pred(R.Len)]);
  end;

  function LessDef(const L, R: TWord): Boolean;
  var
    c: SizeInt;
  begin
    c := CompareByte(L.Start^, R.Start^, Math.Min(L.Len, R.Len));
    if c = 0 then exit(L.Len < R.Len);
    LessDef := c < 0;
  end;

  function Equal(const L, R: TWord): Boolean;
  begin
    if L.Len <> R.Len then exit(False);
    Result := CompareByte(L.Start^, R.Start^, L.Len) = 0;
  end;

  function SplitAndSort(const s: rawbytestring; out aCount: SizeInt; out aBuf: TWordArray; aForceDyn: Boolean): PWord;
  var
    p: PChar absolute s;
    Words: PWord;
    I, Count, CurrLen: SizeInt;
    CurrStart: PChar;
  begin
    if aForceDyn or (System.Length(s) div 2 + System.Length(s) and 1 > MAX_STATIC) then begin
      System.SetLength(aBuf, System.Length(s) div 2 + System.Length(s) and 1);
      Words := Pointer(aBuf);
    end else
      Words := @StBuf[0];

    CurrStart := p;
    CurrLen := 0;
    Count := 0;
    for I := 0 to Pred(System.Length(s)) do
      if p[I] in aStopChars then begin
        if CurrLen = 0 then continue;
        Words[Count].Start := CurrStart;
        Words[Count].Len := CurrLen;
        CurrLen := 0;
        Inc(Count);
      end else begin
        if CurrLen = 0 then
          CurrStart := @p[I];
        Inc(CurrLen);
      end;
    if CurrLen <> 0 then begin
      Words[Count].Start := CurrStart;
      Words[Count].Len := CurrLen;
      Inc(Count);
    end;
    if aLess <> nil then
      THelper.Sort(Words[0..Pred(Count)], @Less)
    else
      THelper.Sort(Words[0..Pred(Count)], @LessDef);
    aCount := Count;
    Result := Words;
  end;

  function SplitMerge(const s: rawbytestring; aSplit: TSplitFun): rawbytestring;
  var
    Words: PWord;
    Buf: TWordArray = nil;
    I, J, Count, Len: SizeInt;
    pR: PChar;
  begin
    Words := aSplit(s, Count, Buf, False);
    System.SetLength(Result, System.Length(s));
    pR := Pointer(Result);
    Len := 0;
    for I := 0 to Pred(Count) do begin
      if I > 0 then begin
        Len += Words[I].Len + 1;
        pR^ := ' ';
        Inc(pR);
      end else
        Len += Words[I].Len;
      for J := 0 to Pred(Words[I].Len) do
        with Words[I] do
          pR[J] := Start[J];
      pR += Words[I].Len;
    end;
    System.SetLength(Result, Len);
  end;

  function SplitMergeSorted(const s: rawbytestring): rawbytestring; inline;
  begin
    Result := SplitMerge(s, @SplitAndSort);
  end;

  function SplitSortedSet(const s: rawbytestring; out aCount: SizeInt; out aBuf: TWordArray; aForceDyn: Boolean): PWord;
  var
    I, J, Count: SizeInt;
  begin
    Result := SplitAndSort(s, Count, aBuf, aForceDyn);
    I := 0;
    J := 0;
    while I < Count do begin
      if I <> J then
        Result[J] := Result[I];
      Inc(I);
      while (I < Count) and Equal(Result[I], Result[J]) do Inc(I);
      Inc(J);
    end;
    aCount := J;
  end;

  function SplitMergeSortedSet(const s: rawbytestring): rawbytestring; inline;
  begin
    Result := SplitMerge(s, @SplitSortedSet);
  end;

  function SimPartial(const L, R: rawbytestring): Double;
  var
    I: SizeInt;
  begin
    if L = '' then
      if R = '' then exit(Double(1.0))
      else exit(Double(0.0))
    else
      if R = '' then exit(Double(0.0));

    Result := Double(0.0);
    if System.Length(L) <= System.Length(R) then
      for I := 0 to System.Length(R) - System.Length(L) do begin
        Result := Math.Max(
          Result,
          SimRatio(PByte(L)[0..Pred(System.Length(L))], PByte(R)[I..I+Pred(System.Length(L))], aLimit, Algo));
        if Result = Double(1.0) then break;
      end
    else
      for I := 0 to System.Length(L) - System.Length(R) do begin
        Result := Math.Max(
          Result,
          SimRatio(PByte(R)[0..Pred(System.Length(R))], PByte(L)[I..I+Pred(System.Length(R))], aLimit, Algo));
        if Result = Double(1.0) then break;
      end;
  end;

  function Merge(aSrcLen: SizeInt; aWords: PWord; const aIndices: TBoolVector): rawbytestring;
  var
    I, J, Len: SizeInt;
    pR: PChar;
    NotFirst: Boolean;
  begin
    System.SetLength(Result, aSrcLen);
    pR := Pointer(Result);
    NotFirst := False;
    Len := 0;
    for I in aIndices do begin
      if NotFirst then begin
        Len += aWords[I].Len + 1;
        pR^ := ' ';
        Inc(pR);
      end else begin
        Len += aWords[I].Len;
        NotFirst := True;
      end;
      for J := 0 to Pred(aWords[I].Len) do
        with aWords[I] do
          pR[J] := Start[J];
      pR += aWords[I].Len;
    end;
    System.SetLength(Result, Len);
  end;

  function SimWordSetPairwise(const L, R: rawbytestring): Double;
  var
    WordsL, WordsR: PWord;
    BufL, BufR: TWordArray;
    IntersectIdx, DiffIdxL, DiffIdxR: TBoolVector;
    I, J, CountL, CountR: SizeInt;
    Intersection, SetL, SetR: rawbytestring;
  begin
    WordsL := SplitSortedSet(L, CountL, BufL, False);
    WordsR := SplitSortedSet(R, CountR, BufR, True);
    IntersectIdx.EnsureCapacity(CountL);
    DiffIdxL.InitRange(CountL);
    DiffIdxR.InitRange(CountR);

    if aLess <> nil then
      for I := 0 to Pred(CountL) do begin
        J := THelper.BinarySearch(WordsR[0..Pred(CountR)], WordsL[I], @Less);
        if J <> NULL_INDEX then begin
          IntersectIdx[I] := True;
          DiffIdxL[I] := False;
          DiffIdxR[J] := False;
        end;
      end
    else
      for I := 0 to Pred(CountL) do begin
        J := THelper.BinarySearch(WordsR[0..Pred(CountR)], WordsL[I], @LessDef);
        if J <> NULL_INDEX then begin
          IntersectIdx[I] := True;
          DiffIdxL[I] := False;
          DiffIdxR[J] := False;
        end;
      end;

    Intersection := Merge(System.Length(L), WordsL, IntersectIdx);
    if (Intersection <> '') and (soPartial in aOptions) then exit(Double(1.0)); ///////
    SetL := Merge(System.Length(L), WordsL, DiffIdxL);
    SetR := Merge(System.Length(R), WordsR, DiffIdxR);

    if Intersection <> '' then begin
      if SetL <> '' then
        SetL := Intersection + ' ' + SetL
      else
        SetL := Intersection;
      if SetR <> '' then
        SetR := Intersection + ' ' + SetR
      else
        SetR := Intersection;
    end;

    if soPartial in aOptions then
      Result := SimPartial(SetL, SetR) /////////
    else begin
      Result := SimRatio(Intersection, SetL, aLimit, Algo);
      if Result = Double(1.0) then exit;
      Result := Math.Max(Result, SimRatio(Intersection, SetR, aLimit, Algo));
      if Result = Double(1.0) then exit;
      Result := Math.Max(Result, SimRatio(SetL, SetR, aLimit, Algo));
    end;
  end;

var
  LocL, LocR: rawbytestring;
begin

  if soIgnoreCase in aOptions then
    if aCaseMap <> nil then begin
      LocL := aCaseMap(L);
      LocR := aCaseMap(R);
    end else begin
      LocL := LowerCase(L);
      LocR := LowerCase(R);
    end
  else begin
    LocL := L;
    LocR := R;
  end;

  case aMode of
    smSimple:
      if soPartial in aOptions then
        Result := SimPartial(SplitMerge(LocL), SplitMerge(LocR))
      else
        Result := SimRatio(SplitMerge(LocL), SplitMerge(LocR), aLimit, Algo);
    smTokenSort:
      if soPartial in aOptions then
        Result := SimPartial(SplitMergeSorted(LocL), SplitMergeSorted(LocR))
      else
        Result := SimRatio(SplitMergeSorted(LocL), SplitMergeSorted(LocR), aLimit, Algo);
    smTokenSet:
      if soPartial in aOptions then
        Result := SimPartial(SplitMergeSortedSet(LocL), SplitMergeSortedSet(LocR))
      else
        Result := SimRatio(SplitMergeSortedSet(LocL), SplitMergeSortedSet(LocR), aLimit, Algo);
  else // smTokenSetEx
    Result := SimWordSetPairwise(LocL, LocR);
  end;
end;

function SimRatioList(const aPattern: rawbytestring; const aValues: array of rawbytestring; aMode: TSimMode;
  const aStopChars: TSysCharSet; const aOptions: TSimOptions; aLimit: Double; Algo: TSeqDistanceAlgo;
  aCaseMap: TSimCaseMap; aLess: TSimLess): specialize TGArray<Double>;
type
  TWord      = record Start: PChar; Len: SizeInt end;
  PWord      = ^TWord;
  TWordArray = array of TWord;
  TSplitFun  = function(const s: rawbytestring; out aCount: SizeInt; out aBuf: TWordArray;
                        aForceDyn: Boolean): PWord is nested;
  THelper    = specialize TGNestedArrayHelper<TWord>;
var
  StBuf: array[0..Pred(MAX_STATIC)] of TWord;

  function SplitMerge(const s: rawbytestring): rawbytestring;
  var
    I, J: SizeInt;
    pS, pR: PChar;
    NewWord: Boolean;
  begin
    if aStopChars = [] then exit(s);
    System.SetLength(Result, System.Length(s));
    pS := Pointer(s);
    pR := Pointer(Result);
    I := 0;
    while (I < System.Length(s)) and (pS[I] in aStopChars) do Inc(I);
    J := 0;
    NewWord := False;
    for I := I to Pred(System.Length(s)) do
      if pS[I] in aStopChars then
        NewWord := True
      else begin
        if NewWord then begin
          pR[J] := ' ';
          Inc(J);
          NewWord := False;
        end;
        pR[J] := pS[I];
        Inc(J);
      end;
    System.SetLength(Result, J);
  end;

  function Less(const L, R: TWord): Boolean; inline;
  begin
    Result := aLess(L.Start[0..Pred(L.Len)], R.Start[0..Pred(R.Len)]);
  end;

  function LessDef(const L, R: TWord): Boolean;
  var
    c: SizeInt;
  begin
    c := CompareByte(L.Start^, R.Start^, Math.Min(L.Len, R.Len));
    if c = 0 then exit(L.Len < R.Len);
    LessDef := c < 0;
  end;

  function Equal(const L, R: TWord): Boolean;
  begin
    if L.Len <> R.Len then exit(False);
    Result := CompareByte(L.Start^, R.Start^, L.Len) = 0;
  end;

  function SplitAndSort(const s: rawbytestring; out aCount: SizeInt; out aBuf: TWordArray; aForceDyn: Boolean): PWord;
  var
    p: PChar absolute s;
    Words: PWord;
    I, Count, CurrLen: SizeInt;
    CurrStart: PChar;
  begin
    if aForceDyn or (System.Length(s) div 2 + System.Length(s) and 1 > MAX_STATIC) then begin
      System.SetLength(aBuf, System.Length(s) div 2 + System.Length(s) and 1);
      Words := Pointer(aBuf);
    end else
      Words := @StBuf[0];

    CurrStart := p;
    CurrLen := 0;
    Count := 0;
    for I := 0 to Pred(System.Length(s)) do
      if p[I] in aStopChars then begin
        if CurrLen = 0 then continue;
        Words[Count].Start := CurrStart;
        Words[Count].Len := CurrLen;
        CurrLen := 0;
        Inc(Count);
      end else begin
        if CurrLen = 0 then
          CurrStart := @p[I];
        Inc(CurrLen);
      end;
    if CurrLen <> 0 then begin
      Words[Count].Start := CurrStart;
      Words[Count].Len := CurrLen;
      Inc(Count);
    end;
    if aLess <> nil then
      THelper.Sort(Words[0..Pred(Count)], @Less)
    else
      THelper.Sort(Words[0..Pred(Count)], @LessDef);
    aCount := Count;
    Result := Words;
  end;

  function SplitMerge(const s: rawbytestring; aSplit: TSplitFun): rawbytestring;
  var
    Words: PWord;
    Buf: TWordArray = nil;
    I, J, Count, Len: SizeInt;
    pR: PChar;
  begin
    Words := aSplit(s, Count, Buf, False);
    System.SetLength(Result, System.Length(s));
    pR := Pointer(Result);
    Len := 0;
    for I := 0 to Pred(Count) do begin
      if I > 0 then begin
        Len += Words[I].Len + 1;
        pR^ := ' ';
        Inc(pR);
      end else
        Len += Words[I].Len;
      for J := 0 to Pred(Words[I].Len) do
        with Words[I] do
          pR[J] := Start[J];
      pR += Words[I].Len;
    end;
    System.SetLength(Result, Len);
  end;

  function SplitMergeSorted(const s: rawbytestring): rawbytestring; inline;
  begin
    Result := SplitMerge(s, @SplitAndSort);
  end;

  function SplitSortedSet(const s: rawbytestring; out aCount: SizeInt; out aBuf: TWordArray; aForceDyn: Boolean): PWord;
  var
    I, J, Count: SizeInt;
  begin
    Result := SplitAndSort(s, Count, aBuf, aForceDyn);
    I := 0;
    J := 0;
    while I < Count do begin
      if I <> J then
        Result[J] := Result[I];
      Inc(I);
      while (I < Count) and Equal(Result[I], Result[J]) do Inc(I);
      Inc(J);
    end;
    aCount := J;
  end;

  function SplitMergeSortedSet(const s: rawbytestring): rawbytestring; inline;
  begin
    Result := SplitMerge(s, @SplitSortedSet);
  end;

  function SimPartial(const L, R: rawbytestring): Double;
  var
    I: SizeInt;
  begin
    if L = '' then
      if R = '' then exit(Double(1.0))
      else exit(Double(0.0))
    else
      if R = '' then exit(Double(0.0));

    Result := Double(0.0);
    if System.Length(L) <= System.Length(R) then
      for I := 0 to System.Length(R) - System.Length(L) do begin
        Result := Math.Max(
          Result,
          SimRatio(PByte(L)[0..Pred(System.Length(L))], PByte(R)[I..I+Pred(System.Length(L))], aLimit, Algo));
        if Result = Double(1.0) then break;
      end
    else
      for I := 0 to System.Length(L) - System.Length(R) do begin
        Result := Math.Max(
          Result,
          SimRatio(PByte(R)[0..Pred(System.Length(R))], PByte(L)[I..I+Pred(System.Length(R))], aLimit, Algo));
        if Result = Double(1.0) then break;
      end;
  end;

  function Merge(aSrcLen: SizeInt; aWords: PWord; const aIndices: TBoolVector): rawbytestring;
  var
    I, J, Len: SizeInt;
    pR: PChar;
    NotFirst: Boolean;
  begin
    System.SetLength(Result, aSrcLen);
    pR := Pointer(Result);
    NotFirst := False;
    Len := 0;
    for I in aIndices do begin
      if NotFirst then begin
        Len += aWords[I].Len + 1;
        pR^ := ' ';
        Inc(pR);
      end else begin
        Len += aWords[I].Len;
        NotFirst := True;
      end;
      for J := 0 to Pred(aWords[I].Len) do
        with aWords[I] do
          pR[J] := Start[J];
      pR += aWords[I].Len;
    end;
    System.SetLength(Result, Len);
  end;

  function ToProperCase(const s: rawbytestring): rawbytestring;
  begin
    if soIgnoreCase in aOptions then
      if aCaseMap <> nil then
        Result := aCaseMap(s)
      else
        Result := LowerCase(s)
    else
      Result := s;
  end;

var
  r: array of Double;

  procedure SimWordSetsPairwise;
  var
    WordsL, WordsR: PWord;
    BufL, BufR: TWordArray;
    IntersectIdx, DiffIdxL, DiffIdxR: TBoolVector;
    I, J, K, CountL, CountR: SizeInt;
    Pattern, Value, Intersection, SetL, SetR: rawbytestring;
  begin
    Pattern := ToProperCase(aPattern);
    WordsL := SplitSortedSet(Pattern, CountL, BufL, False);
    IntersectIdx.EnsureCapacity(CountL);

    for K := 0 to System.High(aValues) do begin
      Value := ToProperCase(aValues[K]);
      WordsR := SplitSortedSet(Value, CountR, BufR, True);
      IntersectIdx.ClearBits;
      DiffIdxL.InitRange(CountL);
      DiffIdxR.InitRange(CountR);

      if aLess <> nil then
        for I := 0 to Pred(CountL) do begin
          J := THelper.BinarySearch(WordsR[0..Pred(CountR)], WordsL[I], @Less);
          if J <> NULL_INDEX then begin
            IntersectIdx[I] := True;
            DiffIdxL[I] := False;
            DiffIdxR[J] := False;
          end;
        end
      else
        for I := 0 to Pred(CountL) do begin
          J := THelper.BinarySearch(WordsR[0..Pred(CountR)], WordsL[I], @LessDef);
          if J <> NULL_INDEX then begin
            IntersectIdx[I] := True;
            DiffIdxL[I] := False;
            DiffIdxR[J] := False;
          end;
        end;

      Intersection := Merge(System.Length(Pattern), WordsL, IntersectIdx);
      if (Intersection <> '') and (soPartial in aOptions) then begin
        r[K] := Double(1.0);
        continue;
      end;
      SetL := Merge(System.Length(Pattern), WordsL, DiffIdxL);
      SetR := Merge(System.Length(Value), WordsR, DiffIdxR);

      if Intersection <> '' then begin
        if SetL <> '' then
          SetL := Intersection + ' ' + SetL
        else
          SetL := Intersection;
        if SetR <> '' then
          SetR := Intersection + ' ' + SetR
        else
          SetR := Intersection;
      end;

      if soPartial in aOptions then
        r[K] := SimPartial(SetL, SetR)
      else begin
        r[K] := SimRatio(Intersection, SetL, aLimit, Algo);
        if r[K] < Double(1.0) then begin
          r[K] := Math.Max(r[K], SimRatio(Intersection, SetR, aLimit, Algo));
          if r[K] < Double(1.0) then
            r[K] := Math.Max(r[K], SimRatio(SetL, SetR, aLimit, Algo));
        end;
      end;
    end;
  end;

var
  LPattern: rawbytestring;
  I: SizeInt;
begin
  if System.Length(aValues) = 0 then exit(nil);
  System.SetLength(r, System.Length(aValues));

  if aMode in [smSimple..smTokenSet] then begin
    case aMode of
      smSimple:     LPattern := SplitMerge(ToProperCase(aPattern));
      smTokenSort:  LPattern := SplitMergeSorted(ToProperCase(aPattern));
      smTokenSet:   LPattern := SplitMergeSortedSet(ToProperCase(aPattern));
    else
    end;
    for I := 0 to System.High(aValues) do begin
      case aMode of
        smSimple:
          if soPartial in aOptions then
            r[I] := SimPartial(LPattern, SplitMerge(ToProperCase(aValues[I])))
          else
            r[I] := SimRatio(LPattern, SplitMerge(ToProperCase(aValues[I])), aLimit, Algo);
        smTokenSort:
          if soPartial in aOptions then
            r[I] := SimPartial(LPattern, SplitMergeSorted(ToProperCase(aValues[I])))
          else
            r[I] := SimRatio(LPattern, SplitMergeSorted(ToProperCase(aValues[I])), aLimit, Algo);
        smTokenSet:
          if soPartial in aOptions then
            r[I] := SimPartial(LPattern, SplitMergeSortedSet(ToProperCase(aValues[I])))
          else
            r[I] := SimRatio(LPattern, SplitMergeSortedSet(ToProperCase(aValues[I])), aLimit, Algo);
      else
      end;
    end;
  end else
    SimWordSetsPairwise;

  Result := r;
end;
{$POP}

{$PUSH}{$WARN 5036 OFF}

function SelectSimilar(const aPattern: rawbytestring; const aValues: array of rawbytestring; aLimit: Double;
  aMode: TSimMode; const aStopChars: TSysCharSet; const aOptions: TSimOptions; Algo: TSeqDistanceAlgo;
  aCaseMap: TSimCaseMap; aLess: TSimLess): specialize TGArray<TRbStrRatio>;
  function Less(const L, R: TRbStrRatio): Boolean;
  begin
    Result := R.Ratio < L.Ratio;
  end;
var
  ratios: array of Double;
  r: array of TRbStrRatio;
  I, J: SizeInt;
begin
  ratios := SimRatioList(aPattern, aValues, aMode, aStopChars, aOptions, aLimit, Algo, aCaseMap, aLess);
  System.SetLength(r, System.Length(ratios));
  J := 0;
  for I := 0 to System.High(ratios) do
    if ratios[I] > Double(0) then begin
      with r[J] do begin
        Value := aValues[I];
        Ratio := ratios[I];
      end;
      Inc(J);
    end;
  System.SetLength(r, J);
  specialize TGNestedArrayHelper<TRbStrRatio>.Sort(r, @Less);
  Result := r;
end;

function IsValidDotQuadIPv4(const s: rawbytestring): Boolean;
type
  TRadix = (raDec, raOct, raHex);
var
  I, OctetIdx, CharIdx: Integer;
  Buf: array[0..3] of AnsiChar;
  Radix: TRadix;
  function OctetInRange: Boolean; inline;
  begin
    if CharIdx = 0 then exit(False);
    case Radix of
      raDec:
        begin
          if CharIdx = 4 then exit(False);
          if CharIdx = 3 then
            begin
              if Buf[0] > '2' then exit(False);
              if Buf[0] = '2' then
                begin
                  if Buf[1] > '5' then exit(False);
                  if (Buf[1] = '5') and (Buf[2] > '5') then exit(False);
                end;
            end;
        end;
      raOct:
        if (CharIdx = 4) and (Buf[1] > '3') then exit(False); //377
      raHex:
        if CharIdx < 3 then exit(False);
    end;
    CharIdx := 0;
    OctetInRange := True;
  end;
var
  p: PAnsiChar absolute s;
begin
  if DWord(System.Length(s) - 7) > DWord(12) then exit(False);
  OctetIdx := 0;
  CharIdx := 0;
  for I := 0 to Pred(System.Length(s)) do
    if p[I] <> '.' then
      begin
        if CharIdx = 4 then exit(False);
        case p[I] of
          '0'..'9':
            begin
              case CharIdx of
                0: Radix := raDec;
                1:
                  if Buf[0] = '0' then
                    begin
                      if p[I] > '7' then exit(False);
                      Radix := raOct;
                    end;
              else
                if (Radix = raOct) and (p[I] > '7') then exit(False);
              end;
            end;
          'X', 'x':
            begin
              if (CharIdx <> 1) or (Buf[0] <> '0') then exit(False);
              Radix := raHex;
            end;
          'A'..'F', 'a'..'f':
            if Radix <> raHex then exit(False);
        else
          exit(False);
        end;
        Buf[CharIdx] := p[I];
        Inc(CharIdx);
      end
    else
      begin
        if (OctetIdx = 3) or not OctetInRange then exit(False);
        Inc(OctetIdx);
      end;
  Result := (OctetIdx = 3) and OctetInRange;
end;

function IsValidDotDecIPv4(const s: rawbytestring): Boolean;
var
  I, OctetIdx, CharIdx: Integer;
  Buf: array[0..3] of AnsiChar;
  function OctetInRange: Boolean; inline;
  begin
    if CharIdx = 0 then exit(False);
    if CharIdx = 3 then
      begin
        if Buf[0] > '2' then exit(False);
        if Buf[0] = '2' then
          begin
            if Buf[1] > '5' then exit(False);
            if (Buf[1] = '5') and (Buf[2] > '5') then exit(False);
          end;
      end;
    CharIdx := 0;
    OctetInRange := True;
  end;
var
  p: PAnsiChar absolute s;
begin
  if DWord(System.Length(s) - 7) > DWord(8) then exit(False);
  OctetIdx := 0;
  CharIdx := 0;
  for I := 0 to Pred(System.Length(s)) do
    case p[I] of
      '0'..'9':
        begin
          if CharIdx = 3 then exit(False);
          if (CharIdx = 1) and (Buf[0] = '0') then exit(False);
          Buf[CharIdx] := p[I];
          Inc(CharIdx);
        end;
      '.':
        begin
          if (OctetIdx = 3) or not OctetInRange then exit(False);
          Inc(OctetIdx);
        end
    else
      exit(False);
    end;
  Result := (OctetIdx = 3) and OctetInRange;
end;
{$POP}

{ TStrSlice }

constructor TStrSlice.Init(p: PAnsiChar; aCount: SizeInt);
begin
  Ptr := p;
  Count := aCount;
end;

class operator TStrSlice.:=(const s: string): TStrSlice;
begin
  Result := TStrSlice.Init(Pointer(s), System.length(s));
end;

class operator TStrSlice.:=(const s: TStrSlice): string;
begin
  System.SetLength(Result, s.Count);
  System.Move(s.Ptr^, Pointer(Result)^, s.Count);
end;

class operator TStrSlice.=(const L, R: TStrSlice): Boolean;
begin
  if L.Count <> R.Count then
    exit(False);
  Result := CompareByte(L.Ptr^, R.Ptr^, L.Count) = 0;
end;

class operator TStrSlice.=(const L: TStrSlice; const R: string): Boolean;
begin
  if L.Count <> System.Length(R) then
    exit(False);
  Result := CompareByte(L.Ptr^, Pointer(R)^, L.Count) = 0;
end;

{ TAnsiStrHelper.TStrEnumerable }

function TAnsiStrHelper.TStrEnumerable.GetCurrent: string;
begin
  Result := System.Copy(FValue, FStartIndex, FLastIndex - FStartIndex);
end;

constructor TAnsiStrHelper.TStrEnumerable.Create(const aValue: string; const aStopChars: TSysCharSet);
begin
  inherited Create;
  FValue := aValue;
  FStopChars := aStopChars;
  FStartIndex := 1;
  FLastIndex := 0;
end;

{$PUSH}{$MACRO ON}
function TAnsiStrHelper.TStrEnumerable.MoveNext: Boolean;
var
  I, Start: SizeInt;
begin
{$DEFINE MoveBodyMacro :=
  Start := 0;
  for I := Succ(FLastIndex) to System.Length(FValue) do
    begin
      if FValue[I] in FStopChars then
        if Start <> 0 then
           break else
      else
        if Start = 0 then
          Start := I;
      Inc(FLastIndex);
    end;
  if Start <> 0 then
    begin
      Inc(FLastIndex);
      FStartIndex := Start;
      exit(True);
    end;
  Result := False
}
  MoveBodyMacro;
end;

procedure TAnsiStrHelper.TStrEnumerable.Reset;
begin
  FStartIndex := 1;
  FLastIndex := 0;
end;

{ TAnsiStrHelper.TSliceEnumerable }

function TAnsiStrHelper.TSliceEnumerable.GetCurrent: TStrSlice;
begin
  Result.Init(@FValue[FStartIndex], FLastIndex - FStartIndex);
end;

constructor TAnsiStrHelper.TSliceEnumerable.Create(const aValue: string; const aStopChars: TSysCharSet);
begin
  inherited Create;
  FValue := aValue;
  FStopChars := aStopChars;
  FStartIndex := 1;
  FLastIndex := 0;
end;

function TAnsiStrHelper.TSliceEnumerable.MoveNext: Boolean;
var
  I, Start: SizeInt;
begin
  MoveBodyMacro;
end;

procedure TAnsiStrHelper.TSliceEnumerable.Reset;
begin
  FStartIndex := 1;
  FLastIndex := 0;
end;

{ TAnsiStrHelper.TWordSliceEnumerator }

procedure TAnsiStrHelper.TWordSliceEnumerator.Init(const aValue: string; const aStopChars: TSysCharSet);
begin
  FValue := aValue;
  FStopChars := aStopChars;
  FStartIndex := 1;
  FLastIndex := 0;
end;

function TAnsiStrHelper.TWordSliceEnumerator.GetCurrent: TStrSlice;
begin
  Result.Init(@FValue[FStartIndex], FLastIndex - FStartIndex);
end;

function TAnsiStrHelper.TWordSliceEnumerator.MoveNext: Boolean;
var
  I, Start: SizeInt;
begin
  MoveBodyMacro;
end;
{$POP}

{ TAnsiStrHelper.TWordSliceEnum }

procedure TAnsiStrHelper.TWordSliceEnum.Init(const aValue: string; const aStopChars: TSysCharSet);
begin
  FValue := aValue;
  FStopChars := aStopChars;
end;

{$PUSH}{$WARN 5092 OFF}
function TAnsiStrHelper.TWordSliceEnum.GetEnumerator: TWordSliceEnumerator;
begin
  Result.Init(FValue, FStopChars);
end;
{$POP}

function TAnsiStrHelper.TWordSliceEnum.ToArray: specialize TGArray<TStrSlice>;
var
  I: SizeInt;
begin
  I := 0;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  with GetEnumerator do
    while MoveNext do
      begin
        if I = System.Length(Result) then
          System.SetLength(Result, I + I);
        Result[I] := Current;
        Inc(I);
      end;
  System.SetLength(Result, I);
end;

{ TAnsiStrHelper }

class function TAnsiStrHelper.Join2(const aSeparator: string; const aValues: array of string): string;
begin
  Result := Join2(aSeparator, aValues, 0, System.Length(aValues));
end;

class function TAnsiStrHelper.Join2(const aSeparator: string; const aValues: array of string;
  aFrom, aCount: SizeInt): string;
var
  I, Len, Last: SizeInt;
  p: PAnsiChar;
begin
  if (System.High(aValues) < 0) or (aFrom > System.High(aValues)) or (aCount <= 0) then
    exit('');
  if aFrom < 0 then
    aFrom := 0;
  Last := Math.Min(Pred(aFrom + aCount), System.High(aValues));
  Len := 0;
  for I := aFrom to Last do
    Len += System.Length(aValues[I]);
  System.SetLength(Result, Len + System.Length(aSeparator) * (Last - aFrom));
  Len := System.Length(aSeparator);
  p := Pointer(Result);
  System.Move(Pointer(aValues[aFrom])^, p^, System.Length(aValues[aFrom]));
  p += System.Length(aValues[aFrom]);
  for I := Succ(aFrom) to Last do
    begin
      System.Move(Pointer(aSeparator)^, p^, Len);
      p += Len;
      System.Move(Pointer(aValues[I])^, p^, System.Length(aValues[I]));
      p += System.Length(aValues[I]);
    end;
end;

class function TAnsiStrHelper.Join(const aSeparator: string; const aValues: array of TStrSlice): string;
begin
  Result := Join(aSeparator, aValues, 0, System.Length(aValues));
end;

class function TAnsiStrHelper.Join(const aSeparator: string; const aValues: array of TStrSlice;
  aFrom, aCount: SizeInt): string;
var
  I, Len, Last: SizeInt;
  p: PAnsiChar;
begin
  if (System.High(aValues) < 0) or (aFrom > System.High(aValues)) or (aCount <= 0) then
    exit('');
  if aFrom < 0 then
    aFrom := 0;
  Last := Math.Min(Pred(aFrom + aCount), System.High(aValues));
  Len := 0;
  for I := aFrom to Last do
    Len += aValues[I].Count;
  System.SetLength(Result, Len + System.Length(aSeparator) * (Last - aFrom));
  Len := System.Length(aSeparator);
  p := Pointer(Result);
  System.Move(aValues[aFrom].Ptr^, p^, aValues[aFrom].Count);
  p += aValues[aFrom].Count;
  for I := Succ(aFrom) to Last do
    begin
      System.Move(Pointer(aSeparator)^, p^, Len);
      p += Len;
      System.Move(aValues[I].Ptr^, p^, aValues[I].Count);
      p += aValues[I].Count;
    end;
end;

class function TAnsiStrHelper.Join(const aSeparator: string; aValues: IStrEnumerable): string;
var
  s: string;
  p: PAnsiChar;
  CharCount: SizeInt;
  procedure EnsureCapacity(aValue: SizeInt); inline;
  begin
    if aValue > System.Length(s) then
      begin
        System.SetLength(s, lgUtils.RoundUpTwoPower(aValue));
        p := Pointer(s);
      end;
  end;
  procedure Append(const s: string); inline;
  begin
    EnsureCapacity(CharCount + System.Length(s));
    System.Move(Pointer(s)^, p[CharCount], System.Length(s));
    CharCount += System.Length(s);
  end;
begin
  CharCount := 0;
  with aValues.GetEnumerator do
    try
      if MoveNext then
        begin
          Append(Current);
          while MoveNext do
            begin
              Append(aSeparator);
              Append(Current);
            end;
        end;
    finally
      Free;
    end;
  System.SetLength(s, CharCount);
  Result := s;
end;

class function TAnsiStrHelper.Join(const aSeparator: string; aValues: ISliceEnumerable): string;
var
  s: string;
  p: PAnsiChar;
  CharCount: SizeInt;
  procedure EnsureCapacity(aValue: SizeInt); inline;
  begin
    if aValue > System.Length(s) then
      begin
        System.SetLength(s, lgUtils.RoundUpTwoPower(aValue));
        p := Pointer(s);
      end;
  end;
  procedure Append(const s: TStrSlice); inline;
  begin
    EnsureCapacity(CharCount + s.Count);
    System.Move(s.Ptr^, p[CharCount], s.Count);
    CharCount += s.Count;
  end;
begin
  CharCount := 0;
  with aValues.GetEnumerator do
    try
      if MoveNext then
        begin
          Append(Current);
          while MoveNext do
            begin
              Append(aSeparator);
              Append(Current);
            end;
        end;
    finally
      Free;
    end;
  System.SetLength(s, CharCount);
  Result := s;
end;

function TAnsiStrHelper.StripWhiteSpaces: string;
begin
  Result := StripChars(WhiteSpaces);
end;

function TAnsiStrHelper.StripChar(aChar: AnsiChar): string;
var
  I, J: SizeInt;
  pRes, pSelf: PAnsiChar;
  c: AnsiChar;
begin
  if Self = '' then
    exit('');
  SetLength(Result, System.Length(Self));
  pSelf := PAnsiChar(Self);
  pRes := PAnsiChar(Result);
  J := 0;
  for I := 0 to Pred(System.Length(Self)) do
    begin
      c := pSelf[I];
      if c <> aChar then
        begin
          pRes[J] := c;
          Inc(J);
        end;
    end;
  SetLength(Result, J);
end;

function TAnsiStrHelper.StripChars(const aChars: TSysCharSet): string;
var
  I, J: SizeInt;
  pRes, pSelf: PAnsiChar;
  c: AnsiChar;
begin
  if Self = '' then
    exit('');
  SetLength(Result, System.Length(Self));
  pSelf := PAnsiChar(Self);
  pRes := PAnsiChar(Result);
  J := 0;
  for I := 0 to Pred(System.Length(Self)) do
    begin
      c := pSelf[I];
      if not (c in aChars) then
        begin
          pRes[J] := c;
          Inc(J);
        end;
    end;
  SetLength(Result, J);
end;

function TAnsiStrHelper.Words(const aStopChars: TSysCharSet): IStrEnumerable;
begin
  Result := TStrEnumerable.Create(Self, aStopChars);
end;

function TAnsiStrHelper.WordSlices(const aStopChars: TSysCharSet): ISliceEnumerable;
begin
  Result := TSliceEnumerable.Create(Self, aStopChars);
end;

{$PUSH}{$WARN 5092 OFF}
function TAnsiStrHelper.WordSliceEnum(const aStopChars: TSysCharSet): TWordSliceEnum;
begin
  Result.Init(Self, aStopChars);
end;
{$POP}

{ TRegexMatch.TStrEnumerable }

function TRegexMatch.TStrEnumerable.GetCurrent: string;
begin
  Result := string(FRegex.Match[0]);
end;

constructor TRegexMatch.TStrEnumerable.Create(aRegex: TRegExpr; const s: string);
begin
  inherited Create;
  FRegex := aRegex;
  FInputString := s;
end;

function TRegexMatch.TStrEnumerable.MoveNext: Boolean;
begin
  if FInCycle then
    Result := FRegex.ExecNext
  else
    begin
      FInCycle := True;
      Result := FRegex.Exec(uRegExpr.RegExprString(FInputString));
    end;
end;

procedure TRegexMatch.TStrEnumerable.Reset;
begin
  FInCycle := False;
end;

{ TRegexMatch }

function TRegexMatch.GetExpression: string;
begin
  Result := string(FRegex.Expression);
end;

function TRegexMatch.GetModifierStr: string;
begin
  Result := string(FRegex.ModifierStr);
end;

procedure TRegexMatch.SetExpression(const aValue: string);
begin
  FRegex.Expression := uRegExpr.RegExprString(aValue);
end;

procedure TRegexMatch.SetModifierStr(const aValue: string);
begin
  FRegex.ModifierStr := uRegExpr.RegExprString(aValue);
end;

constructor TRegexMatch.Create;
begin
  FRegex := TRegExpr.Create;
end;

constructor TRegexMatch.Create(const aRegExpression: string);
begin
  FRegex := TRegExpr.Create(uRegExpr.RegExprString(aRegExpression));
end;

constructor TRegexMatch.Create(const aRegExpression, aModifierStr: string);
begin
  FRegex := TRegExpr.Create(uRegExpr.RegExprString(aRegExpression));
  FRegex.ModifierStr := uRegExpr.RegExprString(aModifierStr);
end;

destructor TRegexMatch.Destroy;
begin
  FRegex.Free;
  inherited;
end;

function TRegexMatch.Matches(const aValue: string): IStrEnumerable;
begin
  Result := TStrEnumerable.Create(FRegex, aValue);
end;

{ TSringListHelper }

function TStringListHelper.AsEnumerable: IStrEnumerable;
begin
  Result := specialize TGClassEnumerable<string, TStringList, TStringsEnumerator>.Create(Self);
end;

{ TBmSearch.TStrEnumerator }

function TBmSearch.TStrEnumerator.GetCurrent: SizeInt;
begin
  Result := Succ(FCurrIndex);
end;

function TBmSearch.TStrEnumerator.MoveNext: Boolean;
var
  I: SizeInt;
begin
  if FCurrIndex < Pred(System.Length(FHeap)) then
    begin
      I := FMatcher^.FindNext(PByte(FHeap), System.Length(FHeap), FCurrIndex);
      if I <> NULL_INDEX then
        begin
          FCurrIndex := I;
          exit(True);
        end;
    end;
  Result := False;
end;

{ TBmSearch.TByteEnumerator }

function TBmSearch.TByteEnumerator.GetCurrent: SizeInt;
begin
  Result := FCurrIndex;
end;

function TBmSearch.TByteEnumerator.MoveNext: Boolean;
var
  I: SizeInt;
begin
  if FCurrIndex < Pred(FHeapLen) then
    begin
      I := FMatcher^.FindNext(FHeap, FHeapLen, FCurrIndex);
      if I <> NULL_INDEX then
        begin
          FCurrIndex := I;
          exit(True);
        end;
    end;
  Result := False;
end;

{ TBmSearch.TStrMatches }

function TBmSearch.TStrMatches.GetEnumerator: TStrEnumerator;
begin
  Result.FCurrIndex := NULL_INDEX;
  Result.FHeap := FHeap;
  Result.FMatcher := FMatcher;
end;

{ TBmSearch.TByteMatches }

function TBmSearch.TByteMatches.GetEnumerator: TByteEnumerator;
begin
  Result.FCurrIndex := NULL_INDEX;
  Result.FHeapLen := FHeapLen;
  Result.FHeap := FHeap;
  Result.FMatcher := FMatcher;
end;

type
  TBcTableType = array[Byte] of Integer;

procedure FillBcTable(pNeedle: PByte; aLen: Integer; var aTable: TBcTableType);
var
  I: Integer;
begin
  specialize TGArrayHelpUtil<Integer>.Fill(aTable, aLen);
  for I := 0 to aLen - 2 do
    aTable[pNeedle[I]] := Pred(aLen - I);
end;

procedure FillGsTable(pNeedle: PByte; aLen: Integer; out aTable: specialize TGArray<Integer>);
var
  I, J, LastPrefix: Integer;
  IsPrefix: Boolean;
begin
  SetLength(aTable, aLen);
  LastPrefix := Pred(aLen);
  for I := Pred(aLen) downto 0 do
    begin
      IsPrefix := True;
      for J := 0 to aLen - I - 2 do
        if (pNeedle[J] <> pNeedle[J + Succ(I)]) then
          begin
            IsPrefix := False;
            break;
          end;
      if IsPrefix then
        LastPrefix := Succ(I);
      aTable[I] := LastPrefix + aLen - Succ(I);
    end;
  for I := 0 to aLen - 2 do
    begin
      J := 0;
      while (pNeedle[I - J] = pNeedle[Pred(aLen - J)]) and (J < I) do
        Inc(J);
      if pNeedle[I - J] <> pNeedle[Pred(aLen - J)] then
        aTable[Pred(aLen - J)] := Pred(aLen + J - I);
    end;
end;

{ TBmSearch }

function TBmSearch.DoFind(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
var
  J, NeedLast: SizeInt;
  p: PByte absolute FNeedle;
begin
  NeedLast := Pred(System.Length(FNeedle));
  while I < aHeapLen do
    begin
      while (I < aHeapLen) and (aHeap[I] <> p[NeedLast]) do
        I += FBcShift[aHeap[I]];
      if I >= aHeapLen then break;
      J := Pred(NeedLast);
      Dec(I);
      while (J <> NULL_INDEX) and (aHeap[I] = p[J]) do
        begin
          Dec(I);
          Dec(J);
        end;
      if J = NULL_INDEX then
        exit(Succ(I))
      else
        I += FGsShift[J];
    end;
  Result := NULL_INDEX;
end;

function TBmSearch.FindNext(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
begin
  if I = NULL_INDEX then
    Result := DoFind(aHeap, aHeapLen, I + System.Length(FNeedle))
  else
    Result := DoFind(aHeap, aHeapLen, I + FGsShift[0]);
end;

function TBmSearch.Find(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
begin
  Result := DoFind(aHeap, aHeapLen, I + Pred(System.Length(FNeedle)));
end;

constructor TBmSearch.Create(const aPattern: rawbytestring);
begin
  FGsShift := nil;
  if aPattern <> '' then
    begin
      FNeedle := aPattern;
      FillBcTable(Pointer(FNeedle), System.Length(FNeedle), FBcShift);
      FillGsTable(Pointer(FNeedle), System.Length(FNeedle), FGsShift);
    end
  else
    FNeedle := '';
end;

constructor TBmSearch.Create(const aPattern: array of Byte);
begin
  FGsShift := nil;
  System.SetLength(FNeedle, System.Length(aPattern));
  if System.Length(aPattern) <> 0 then
    begin
      System.Move(aPattern[0], Pointer(FNeedle)^, System.Length(aPattern));
      FillBcTable(Pointer(FNeedle), System.Length(FNeedle), FBcShift);
      FillGsTable(Pointer(FNeedle), System.Length(FNeedle), FGsShift);
    end;
end;

function TBmSearch.Matches(const s: rawbytestring): TStrMatches;
begin
  if FNeedle <> '' then
    Result.FHeap := s
  else
    Result.FHeap := '';
  Result.FMatcher := @Self;
end;

function TBmSearch.Matches(const a: array of Byte): TByteMatches;
begin
  if FNeedle <> '' then
    Result.FHeapLen := System.Length(a)
  else
    Result.FHeapLen := 0;
  if System.Length(a) <> 0 then
    Result.FHeap := @a[0]
  else
    Result.FHeap := nil;
  Result.FMatcher := @Self;
end;

function TBmSearch.NextMatch(const s: rawbytestring; aOffset: SizeInt): SizeInt;
begin
  if (FNeedle = '') or (s = '') then exit(0);
  if aOffset < 1 then
    aOffset := 1;
  Result := Succ(Find(PByte(s), System.Length(s), Pred(aOffset)));
end;

function TBmSearch.NextMatch(const a: array of Byte; aOffset: SizeInt): SizeInt;
begin
  if (FNeedle = '') or (System.Length(a) = 0) then exit(NULL_INDEX);
  if aOffset < 0 then
    aOffset := 0;
  Result := Find(@a[0], System.Length(a), aOffset);
end;

function TBmSearch.FindMatches(const s: rawbytestring): TIntArray;
var
  I, J: SizeInt;
begin
  Result := nil;
  if (FNeedle = '') or (s = '') then exit;
  I := NULL_INDEX;
  J := 0;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  repeat
    I := FindNext(PByte(s), System.Length(s), I);
    if I <> NULL_INDEX then
      begin
        if System.Length(Result) = J then
          System.SetLength(Result, J * 2);
        Result[J] := Succ(I);
        Inc(J);
      end;
  until I = NULL_INDEX;
  System.SetLength(Result, J);
end;

function TBmSearch.FindMatches(const a: array of Byte): TIntArray;
var
  I, J: SizeInt;
begin
  Result := nil;
  if (FNeedle = '') or (System.Length(a) = 0) then exit;
  I := NULL_INDEX;
  J := 0;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  repeat
    I := FindNext(@a[0], System.Length(a), I);
    if I <> NULL_INDEX then
      begin
        if System.Length(Result) = J then
          System.SetLength(Result, J * 2);
        Result[J] := I;
        Inc(J);
      end;
  until I = NULL_INDEX;
  System.SetLength(Result, J);
end;

{ TBmhrSearch.TStrEnumerator }

function TBmhrSearch.TStrEnumerator.GetCurrent: SizeInt;
begin
   Result := Succ(FCurrIndex);
end;

function TBmhrSearch.TStrEnumerator.MoveNext: Boolean;
var
  I: SizeInt;
begin
  if FCurrIndex < Pred(System.Length(FHeap)) then
    begin
      I := FMatcher^.FindNext(PByte(FHeap), System.Length(FHeap), FCurrIndex);
      if I <> NULL_INDEX then
        begin
          FCurrIndex := I;
          exit(True);
        end;
    end;
  Result := False;
end;

{ TBmhrSearch.TByteEnumerator }

function TBmhrSearch.TByteEnumerator.GetCurrent: SizeInt;
begin
  Result := FCurrIndex;
end;

function TBmhrSearch.TByteEnumerator.MoveNext: Boolean;
var
  I: SizeInt;
begin
  if FCurrIndex < Pred(FHeapLen) then
    begin
      I := FMatcher^.FindNext(FHeap, FHeapLen, FCurrIndex);
      if I <> NULL_INDEX then
        begin
          FCurrIndex := I;
          exit(True);
        end;
    end;
  Result := False;
end;

{ TBmhrSearch.TStrMatches }

function TBmhrSearch.TStrMatches.GetEnumerator: TStrEnumerator;
begin
  Result.FCurrIndex := NULL_INDEX;
  Result.FHeap := FHeap;
  Result.FMatcher := FMatcher;
end;

{ TBmhrSearch.TByteMatches }

function TBmhrSearch.TByteMatches.GetEnumerator: TByteEnumerator;
begin
  Result.FCurrIndex := NULL_INDEX;
  Result.FHeapLen := FHeapLen;
  Result.FHeap := FHeap;
  Result.FMatcher := FMatcher;
end;

{ TBmhrSearch }

function TBmhrSearch.Find(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
var
  NeedLast, J: Integer;
  p: PByte absolute FNeedle;
begin
  case System.Length(FNeedle) of
    1:
      begin
        J := IndexByte(aHeap[I], aHeapLen - I, p^);
        if J < 0 then exit(J);
        exit(I + J);
      end;
    2:
      while I <= aHeapLen - 2 do
        begin
          if(aHeap[I + 1] = p[1]) and (aHeap[I] = p^) then
            exit(I);
          I += FBcShift[aHeap[I + 1]];
        end;
    3:
      while I <= aHeapLen - 3 do
        begin
          if(aHeap[I + 2] = p[2]) and (aHeap[I] = p^) and
            (aHeap[I + 1] = p[1]) then
            exit(I);
          I += FBcShift[aHeap[I + 2]];
        end;
  else
    begin
      NeedLast := Pred(System.Length(FNeedle));
      while I <= aHeapLen - Succ(NeedLast) do
        begin
          if(aHeap[I + NeedLast] = p[NeedLast]) and (aHeap[I] = p^) and
            (aHeap[I + NeedLast shr 1] = p[NeedLast shr 1]) and
            (CompareByte(aHeap[Succ(I)], p[1], Pred(NeedLast)) = 0) then
            exit(I);
          I += FBcShift[aHeap[I + NeedLast]];
        end;
    end;
  end;
  Result := NULL_INDEX;
end;

function TBmhrSearch.FindNext(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
begin
  if I > aHeapLen - System.Length(FNeedle) then exit(NULL_INDEX);
  if I = NULL_INDEX then
    I := 0
  else
    I += FBcShift[aHeap[I + Pred(System.Length(FNeedle))]];
  Result := Find(aHeap, aHeapLen, I);
end;

constructor TBmhrSearch.Create(const aPattern: rawbytestring);
begin
  if aPattern <> '' then
    begin
      FNeedle := aPattern;
      FillBcTable(Pointer(FNeedle), System.Length(FNeedle), FBcShift);
    end
  else
    FNeedle := '';
end;

constructor TBmhrSearch.Create(const aPattern: array of Byte);
begin
  System.SetLength(FNeedle, System.Length(aPattern));
  if System.Length(aPattern) <> 0 then
    begin
      System.Move(aPattern[0], Pointer(FNeedle)^, System.Length(aPattern));
      FillBcTable(Pointer(FNeedle), System.Length(FNeedle), FBcShift);
    end;
end;

function TBmhrSearch.Matches(const s: rawbytestring): TStrMatches;
begin
  if FNeedle <> '' then
    Result.FHeap := s
  else
    Result.FHeap := '';
  Result.FMatcher := @Self;
end;

function TBmhrSearch.Matches(const a: array of Byte): TByteMatches;
begin
  if FNeedle <> '' then
    Result.FHeapLen := System.Length(a)
  else
    Result.FHeapLen := 0;
  if System.Length(a) <> 0 then
    Result.FHeap := @a[0]
  else
    Result.FHeap := nil;
  Result.FMatcher := @Self;
end;

function TBmhrSearch.NextMatch(const s: rawbytestring; aOffset: SizeInt): SizeInt;
begin
  if (FNeedle = '') or (s = '') then exit(0);
  if aOffset < 1 then
    aOffset := 1;
  Result := Succ(Find(PByte(s), System.Length(s), Pred(aOffset)));
end;

function TBmhrSearch.NextMatch(const a: array of Byte; aOffset: SizeInt): SizeInt;
begin
  if (FNeedle = '') or (System.Length(a) = 0) then exit(NULL_INDEX);
  if aOffset < 0 then
    aOffset := 0;
  Result := Find(@a[0], System.Length(a), aOffset);
end;

function TBmhrSearch.FindMatches(const s: rawbytestring): TIntArray;
var
  I, J: SizeInt;
begin
  Result := nil;
  if (FNeedle = '') or (s = '') then exit;
  I := NULL_INDEX;
  J := 0;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  repeat
    I := FindNext(PByte(s), System.Length(s), I);
    if I <> NULL_INDEX then
      begin
        if System.Length(Result) = J then
          System.SetLength(Result, J * 2);
        Result[J] := Succ(I);
        Inc(J);
      end;
  until I = NULL_INDEX;
  System.SetLength(Result, J);
end;

function TBmhrSearch.FindMatches(const a: array of Byte): TIntArray;
var
  I, J: SizeInt;
begin
  Result := nil;
  if (FNeedle = '') or (System.Length(a) = 0) then exit;
  I := NULL_INDEX;
  J := 0;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  repeat
    I := FindNext(@a[0], System.Length(a), I);
    if I <> NULL_INDEX then
      begin
        if System.Length(Result) = J then
          System.SetLength(Result, J * 2);
        Result[J] := I;
        Inc(J);
      end;
  until I = NULL_INDEX;
  System.SetLength(Result, J);
end;

{ TBmSearchCI.TEnumerator }

function TBmSearchCI.TEnumerator.GetCurrent: SizeInt;
begin
  Result := Succ(FCurrIndex);
end;

function TBmSearchCI.TEnumerator.MoveNext: Boolean;
var
  I: SizeInt;
begin
  if FCurrIndex < Pred(System.Length(FHeap)) then
    begin
      I := FMatcher^.FindNext(PByte(FHeap), System.Length(FHeap), FCurrIndex);
      if I <> NULL_INDEX then
        begin
          FCurrIndex := I;
          exit(True);
        end;
    end;
  Result := False;
end;

{ TBmSearchCI.TMatches }

function TBmSearchCI.TMatches.GetEnumerator: TEnumerator;
begin
  Result.FCurrIndex := NULL_INDEX;
  Result.FHeap := FHeap;
  Result.FMatcher := FMatcher;
end;

{ TBmSearchCI }

procedure TBmSearchCI.FillMap;
var
  I: Integer;
begin
  for I := 0 to 255 do
    FCaseMap[I] := Ord(LowerCase(Char(I)));
end;

procedure TBmSearchCI.FillMap(aMap: TCaseMapFun);
var
  I: Integer;
begin
  for I := 0 to 255 do
    FCaseMap[I] := Ord(aMap(Char(I)));
end;

procedure TBmSearchCI.FillMap(const aTable: TCaseMapTable);
begin
  FCaseMap := aTable;
end;

function TBmSearchCI.DoFind(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
var
  J, NeedLast: SizeInt;
  p: PByte absolute FNeedle;
begin
  NeedLast := Pred(System.Length(FNeedle));
  while I < aHeapLen do
    begin
      while (I < aHeapLen) and (FCaseMap[aHeap[I]] <> p[NeedLast]) do
        I += FBcShift[FCaseMap[aHeap[I]]];
      if I >= aHeapLen then break;
      J := Pred(NeedLast);
      Dec(I);
      while (J <> NULL_INDEX) and (FCaseMap[aHeap[I]] = p[J]) do
        begin
          Dec(I);
          Dec(J);
        end;
      if J = NULL_INDEX then
        exit(Succ(I))
      else
        I += FGsShift[J];
    end;
  Result := NULL_INDEX;
end;

function TBmSearchCI.FindNext(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
begin
  if I = NULL_INDEX then
    Result := DoFind(aHeap, aHeapLen, I + System.Length(FNeedle))
  else
    Result := DoFind(aHeap, aHeapLen, I + FGsShift[0]);
end;

function TBmSearchCI.Find(aHeap: PByte; const aHeapLen: SizeInt; I: SizeInt): SizeInt;
begin
  Result := DoFind(aHeap, aHeapLen, I + Pred(System.Length(FNeedle)));
end;

constructor TBmSearchCI.Create(const aPattern: rawbytestring);
var
  I: Integer;
  p: PByte;
begin
  FGsShift := nil;
  FNeedle := '';
  FillMap;
  if aPattern <> '' then
    begin
      System.SetLength(FNeedle, System.Length(aPattern));
      p := PByte(FNeedle);
      for I := 1 to System.Length(aPattern) do
        p[Pred(I)] := FCaseMap[Ord(aPattern[I])];
      FillBcTable(Pointer(FNeedle), System.Length(FNeedle), FBcShift);
      FillGsTable(Pointer(FNeedle), System.Length(FNeedle), FGsShift);
    end;
end;

constructor TBmSearchCI.Create(const aPattern: rawbytestring; aMap: TCaseMapFun);
var
  I: Integer;
  p: PByte;
begin
  FGsShift := nil;
  FNeedle := '';
  FillMap(aMap);
  if aPattern <> '' then
    begin
      System.SetLength(FNeedle, System.Length(aPattern));
      p := PByte(FNeedle);
      for I := 1 to System.Length(aPattern) do
        p[Pred(I)] := FCaseMap[Ord(aPattern[I])];
      FillBcTable(Pointer(FNeedle), System.Length(FNeedle), FBcShift);
      FillGsTable(Pointer(FNeedle), System.Length(FNeedle), FGsShift);
    end;
end;

constructor TBmSearchCI.Create(const aPattern: rawbytestring; const aTable: TCaseMapTable);
var
  I: Integer;
  p: PByte;
begin
  FGsShift := nil;
  FNeedle := '';
  FillMap(aTable);
  if aPattern <> '' then
    begin
      System.SetLength(FNeedle, System.Length(aPattern));
      p := PByte(FNeedle);
      for I := 1 to System.Length(aPattern) do
        p[Pred(I)] := FCaseMap[Ord(aPattern[I])];
      FillBcTable(Pointer(FNeedle), System.Length(FNeedle), FBcShift);
      FillGsTable(Pointer(FNeedle), System.Length(FNeedle), FGsShift);
    end;
end;

procedure TBmSearchCI.Update(const aPattern: rawbytestring);
var
  I: Integer;
  p: PByte;
begin
  FGsShift := nil;
  FNeedle := '';
  if aPattern <> '' then
    begin
      System.SetLength(FNeedle, System.Length(aPattern));
      p := PByte(FNeedle);
      for I := 1 to System.Length(aPattern) do
        p[Pred(I)] := FCaseMap[Ord(aPattern[I])];
      FillBcTable(Pointer(FNeedle), System.Length(FNeedle), FBcShift);
      FillGsTable(Pointer(FNeedle), System.Length(FNeedle), FGsShift);
    end;
end;

function TBmSearchCI.Matches(const s: rawbytestring): TMatches;
begin
  if FNeedle <> '' then
    Result.FHeap := s
  else
    Result.FHeap := '';
  Result.FMatcher := @Self;
end;

function TBmSearchCI.NextMatch(const s: rawbytestring; aOffset: SizeInt): SizeInt;
begin
  if (FNeedle = '') or (s = '') then exit(0);
  if aOffset < 1 then
    aOffset := 1;
  Result := Succ(Find(PByte(s), System.Length(s), Pred(aOffset)));
end;

function TBmSearchCI.FindMatches(const s: rawbytestring): TIntArray;
var
  I, J: SizeInt;
begin
  Result := nil;
  if (FNeedle = '') or (s = '') then exit;
  I := NULL_INDEX;
  J := 0;
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  repeat
    I := FindNext(PByte(s), System.Length(s), I);
    if I <> NULL_INDEX then
      begin
        if System.Length(Result) = J then
          System.SetLength(Result, J * 2);
        Result[J] := Succ(I);
        Inc(J);
      end;
  until I = NULL_INDEX;
  System.SetLength(Result, J);
end;

{ TACSearchFsm }

function TACSearchFsm.TestOnMatch(const m: TMatch): Boolean;
begin
  Result := FOnMatchHandler(m);
end;

function TACSearchFsm.TestNestMatch(const m: TMatch): Boolean;
begin
  Result := FNestMatchHandler(m);
end;

procedure TACSearchFsm.RegisterMatchHandler(h: TOnMatch);
begin
  FOnMatchHandler := h;
  FOnMatch := @TestOnMatch;
end;

procedure TACSearchFsm.RegisterMatchHandler(h: TNestMatch);
begin
  FNestMatchHandler := h;
  FOnMatch := @TestNestMatch;
end;

function TACSearchFsm.NewNode: SizeInt;
begin
{$IFDEF CPU64}
  if NodeCount = MaxInt then
    raise ELGMaxItemsExceed.CreateFmt(SEMaxNodeCountExceedFmt, [MaxInt]);
{$ENDIF CPU64}
  if FNodeCount = System.Length(FTrie) then
    System.SetLength(FTrie, NodeCount * 2);
  Result := NodeCount;
  Inc(FNodeCount);
  System.SetLength(FTrie[Result].NextMove, AlphabetSize);
end;

procedure TACSearchFsm.BuildCharMap(const aList: array of rawbytestring);
var
  I: SizeInt;
  s: string;
begin
  System.FillChar(FCharMap, SizeOf(FCharMap), $ff);
  for s in aList do
    for I := 1 to System.Length(s) do
      if FCharMap[Byte(s[I])] = -1 then
        begin
          FCharMap[Byte(s[I])] := AlphabetSize;
          Inc(FAlphabetSize);
        end;
end;

procedure TACSearchFsm.AddPattern(const aValue: rawbytestring; aIndex: SizeInt);
var
  I: SizeInt;
  Curr, Next, Code: Int32;
begin
  if aValue = '' then exit;
  Curr := 0;
  for I := 1 to System.Length(aValue) do
    begin
      Code := FCharMap[Byte(aValue[I])];
      Next := FTrie[Curr].NextMove[Code];
      // if no transition is found for current character, just add a new one
      if Next = 0 then
        begin
          Next := NewNode;
          FTrie[Curr].NextMove[Code] := Next;
        end
      else;
      Curr := Next;
    end;
  with FTrie[Curr] do
    if Length = 0 then
      begin
        Inc(FWordCount);
        Index := aIndex;
        Length := System.Length(aValue);
      end;
end;

procedure TACSearchFsm.BuildFsm;
var
  Queue: specialize TGLiteQueue<Int32>;
  Failure: array of Int32;
  Curr, Next, Fail, Link, Code: Int32;
begin // simple BFS
  System.SetLength(Failure, NodeCount);
  for Curr in FTrie[0].NextMove do
    if Curr <> 0 then
      Queue.Enqueue(Curr);
  while Queue.TryDequeue(Curr) do
    for Code := 0 to Pred(AlphabetSize) do
      if FTrie[Curr].NextMove[Code] <> 0 then
        begin
          Next := FTrie[Curr].NextMove[Code];
          Queue.Enqueue(Next);
          Fail := Curr;
          repeat
            Fail := Failure[Fail];
            Link := FTrie[Fail].NextMove[Code];
            if Link <> 0 then
              begin
                Failure[Next] := Link;
                if FTrie[Link].Length <> 0 then
                  FTrie[Next].Output := Link
                else
                  FTrie[Next].Output := FTrie[Link].Output;
                break;
              end;
          until Fail = 0;
        end
      else
        FTrie[Curr].NextMove[Code] := FTrie[Failure[Curr]].NextMove[Code];
end;

function TACSearchFsm.TestInput(const s: rawbytestring; var aOffset, aCount: SizeInt): Boolean;
begin
  if (s = '') or (PatternCount = 0) then exit(False);
  if aOffset < 1 then aOffset := 1;
  if aCount < 1 then
    aCount := System.Length(s)
  else
    aCount := Math.Min(Pred(aOffset + aCount), System.Length(s));
  Result := aOffset <= aCount;
end;

function TACSearchFsm.DoFindNoOverlap(const s: rawbytestring; aOffset, aCount: SizeInt): TMatchArray;
var
  Matches: array of TMatch;
  MatchCount: SizeInt;
  procedure AddMatch(const m: TMatch);
  begin
    if MatchCount = System.Length(Matches) then
      System.SetLength(Matches, MatchCount * 2);
    Matches[MatchCount] := m;
    Inc(MatchCount);
  end;
var
  I: SizeInt;
  State, Code: Int32;
begin
  if not TestInput(s, aOffset, aCount) then exit(nil);
  System.SetLength(Matches, ARRAY_INITIAL_SIZE);
  MatchCount := 0;
  State := 0;
  for I := aOffset to aCount do
    begin
      Code := FCharMap[Byte(s[I])];
      if Code = -1 then
        begin
          State := 0;
          continue;
        end;
      State := FTrie[State].NextMove[Code];
      if State = 0 then continue;
      with FTrie[State] do
        if Length <> 0 then
          begin
            AddMatch(TMatch.Make(Succ(I - Length), Length, Index));
            State := 0;
            continue;
          end;
      if FTrie[State].Output <> 0 then
        with FTrie[FTrie[State].Output] do
          begin
            AddMatch(TMatch.Make(Succ(I - Length), Length, Index));
            State := 0;
          end;
    end;
  System.SetLength(Matches, MatchCount);
  Result := Matches;
end;

function TACSearchFsm.DoFindAll(const s: rawbytestring; aOffset, aCount: SizeInt): TMatchArray;
var
  Matches: array of TMatch;
  MatchCount: SizeInt;
  procedure AddMatch(const m: TMatch);
  begin
    if MatchCount = System.Length(Matches) then
      System.SetLength(Matches, MatchCount * 2);
    Matches[MatchCount] := m;
    Inc(MatchCount);
  end;
var
  I: SizeInt;
  State, Tmp, Code: Int32;
begin
  if not TestInput(s, aOffset, aCount) then exit(nil);
  System.SetLength(Matches, ARRAY_INITIAL_SIZE);
  MatchCount := 0;
  State := 0;
  for I := aOffset to aCount do
    begin
      Code := FCharMap[Byte(s[I])];
      if Code = -1 then
        begin
          State := 0;
          continue;
        end;
      State := FTrie[State].NextMove[Code];
      if State = 0 then continue;
      with FTrie[State] do
        if Length <> 0 then
          AddMatch(TMatch.Make(Succ(I - Length), Length, Index));
      Tmp := State;
      while FTrie[Tmp].Output <> 0 do
        begin
          Tmp := FTrie[Tmp].Output;
          with FTrie[Tmp] do
            AddMatch(TMatch.Make(Succ(I - Length), Length, Index));
        end;
    end;
  System.SetLength(Matches, MatchCount);
  Result := Matches;
end;

procedure TACSearchFsm.DoSearch(const s: rawbytestring; aOffset, aCount: SizeInt);
var
  I: SizeInt;
  State, Tmp, Code: Int32;
begin
  if not TestInput(s, aOffset, aCount) then exit;
  State := 0;
  for I := aOffset to aCount do
    begin
      Code := FCharMap[Byte(s[I])];
      if Code = -1 then
        begin
          State := 0;
          continue;
        end;
      State := FTrie[State].NextMove[Code];
      if State = 0 then continue;
      with FTrie[State] do
        if Length <> 0 then
          if not FOnMatch(TMatch.Make(Succ(I - Length), Length, Index)) then exit;
      Tmp := State;
      while FTrie[Tmp].Output <> 0 do
        begin
          Tmp := FTrie[Tmp].Output;
          with FTrie[Tmp] do
            if not FOnMatch(TMatch.Make(Succ(I - Length), Length, Index)) then exit;
        end;
    end;
end;

function MatchCompareLF(const L, R: TIndexMatch): Boolean;
begin
  if L.Offset = R.Offset then
    Result := L.Index < R.Index
  else
    Result := L.Offset < R.Offset;
end;

function MatchCompareLL(const L, R: TIndexMatch): Boolean;
begin
  if L.Offset = R.Offset then
    Result := L.Length > R.Length
  else
    Result := L.Offset < R.Offset;
end;

function MatchCompareLS(const L, R: TIndexMatch): Boolean;
begin
  if L.Offset = R.Offset then
    Result := L.Length < R.Length
  else
    Result := L.Offset < R.Offset;
end;

class procedure TACSearchFsm.DoFilterMatches(var aMatches: TMatchArray; aMode: TSetMatchMode);
var
  Count, I, Len, Ofs: SizeInt;
begin
  if aMatches = nil then exit;
  case aMode of
    smmDefault, smmNonOverlapping: exit;
    smmLeftmostFirst:    TSortHelper.Sort(aMatches, @MatchCompareLF);
    smmLeftmostLongest:  TSortHelper.Sort(aMatches, @MatchCompareLL);
    smmLeftmostShortest: TSortHelper.Sort(aMatches, @MatchCompareLS);
  end;
  Count := 0;
  I := 0;
  Len := System.Length(aMatches);
  repeat
    Ofs := aMatches[Count].Offset + aMatches[Count].Length;
    Inc(Count);
    Inc(I);
    while (I < Len) and (aMatches[I].Offset < Ofs) do Inc(I);
    if I >= Len then break;
    if I <> Count then
      aMatches[Count] := aMatches[I];
  until False;
  System.SetLength(aMatches, Count);
end;

class function TACSearchFsm.FilterMatches(const aSource: array of TMatch; aMode: TSetMatchMode): TMatchArray;
begin
  Result := specialize TGArrayHelpUtil<TMatch>.CreateCopy(aSource);
  DoFilterMatches(Result, aMode);
end;

constructor TACSearchFsm.Create(const aPatternList: array of rawbytestring);
var
  I: SizeInt;
begin
  //todo: any failure conditions depending on the size or (???) of the input?
  BuildCharMap(aPatternList);
  System.SetLength(FTrie, ARRAY_INITIAL_SIZE);
  NewNode;
  for I := 0 to System.High(aPatternList) do
    AddPattern(aPatternList[I], I);
  System.SetLength(FTrie, FNodeCount);
  BuildFsm;
end;

constructor TACSearchFsm.Create(aPatternEnum: IStrEnumerable);
begin
  Create(aPatternEnum.ToArray);
end;

constructor TACSearchFsm.Create(aFsm: TACSearchFsm);
begin
  FTrie := aFsm.FTrie;
  FCharMap := aFsm.FCharMap;
  FNodeCount := aFsm.FNodeCount;
  FWordCount := aFsm.FWordCount;
  FAlphabetSize := aFsm.FAlphabetSize;
end;

function TACSearchFsm.IndexOfPattern(const aValue: rawbytestring): SizeInt;
var
  I, Curr, Next, Code: Int32;
begin
  Result := NULL_INDEX;
  if aValue = '' then exit;
  Curr := 0;
  for I := 1 to System.Length(aValue) do
    begin
      Code := FCharMap[Byte(aValue[I])];
      if Code = -1 then exit;
      Next := FTrie[Curr].NextMove[Code];
      if Next = 0 then exit;
      Curr := Next;
    end;
  with FTrie[Curr] do
    if Length <> 0 then
      Result := Index;
end;

function TACSearchFsm.IsMatch(const aValue: rawbytestring): Boolean;
begin
  Result := IndexOfPattern(aValue) <> NULL_INDEX;
end;

{$PUSH}{$WARN 5089 OFF}
function TACSearchFsm.FirstMatch(const aText: rawbytestring; aMode: TSetMatchMode; aOffset, aCount: SizeInt): TMatch;
var
  Matches: specialize TGLiteVector<TMatch>;
  I: SizeInt;
  State, NextState, Code: Int32;
begin
  Result := TMatch.Make(0, 0, NULL_INDEX);
  if not TestInput(aText, aOffset, aCount) then exit;
  State := 0;
  for I := aOffset to aCount do
    begin
      Code := FCharMap[Byte(aText[I])];
      if Code = -1 then
        NextState := 0
      else
        NextState := FTrie[State].NextMove[Code];
      if NextState = 0 then
        if State = 0 then
          continue
        else
          break;
      State := NextState;
      with FTrie[NextState] do
        if Length <> 0 then
          if aMode < smmLeftmostFirst then
            exit(TMatch.Make(Succ(I - Length), Length, Index))
          else
            Matches.Add(TMatch.Make(Succ(I - Length), Length, Index));
      while FTrie[NextState].Output <> 0 do
        begin
          NextState := FTrie[NextState].Output;
          with FTrie[NextState] do
            if aMode < smmLeftmostFirst then
              exit(TMatch.Make(Succ(I - Length), Length, Index))
            else
              Matches.Add(TMatch.Make(Succ(I - Length), Length, Index));
        end;
    end;
  if Matches.NonEmpty then
    case aMode of
      smmLeftmostFirst:    TVectHelper.FindMin(Matches, Result, @MatchCompareLF);
      smmLeftmostLongest:  TVectHelper.FindMin(Matches, Result, @MatchCompareLL);
      smmLeftmostShortest: TVectHelper.FindMin(Matches, Result, @MatchCompareLS);
    else
    end;
end;
{$POP}

function TACSearchFsm.FindMatches(const aText: rawbytestring; aMode: TSetMatchMode; aOffset, aCount: SizeInt): TMatchArray;
begin
  if aMode = smmNonOverlapping then
    exit(DoFindNoOverlap(aText, aOffset, aCount));
  Result := DoFindAll(aText, aOffset, aCount);
  DoFilterMatches(Result, aMode);
end;

procedure TACSearchFsm.Search(const aText: rawbytestring; aOnMatch: TOnMatch; aOffset, aCount: SizeInt);
begin
  if aOnMatch = nil then exit;
  RegisterMatchHandler(aOnMatch);
  DoSearch(aText, aOffset, aCount);
end;

procedure TACSearchFsm.Search(const aText: rawbytestring; aOnMatch: TNestMatch; aOffset, aCount: SizeInt);
begin
  if aOnMatch = nil then exit;
  RegisterMatchHandler(aOnMatch);
  DoSearch(aText, aOffset, aCount);
end;

function TACSearchFsm.ContainsMatch(const aText: rawbytestring; aOffset, aCount: SizeInt): Boolean;
var
  I: SizeInt;
  State, Code: Int32;
begin
  if not TestInput(aText, aOffset, aCount) then exit(False);
  State := 0;
  for I := aOffset to aCount do
    begin
      Code := FCharMap[Byte(aText[I])];
      if Code = -1 then
        begin
          State := 0;
          continue;
        end;
      State := FTrie[State].NextMove[Code];
      if State = 0 then continue;
      if FTrie[State].Length <> 0 then exit(True);
      if FTrie[State].Output <> 0 then exit(True);
    end;
  Result := False;
end;

end.

