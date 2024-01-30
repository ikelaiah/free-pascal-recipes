<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a name="readme-top"></a>


<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/ikelaiah/free-pascal-snippets">
    <img src="Images/logo.png" alt="Logo" width="256" height="256">
  </a>

<h3 align="center">Free Pascal Snippets</h3>

  <p align="center">
    This repository contains (work in progress) Free Pascal code snippets that I've put together while learning Object Pascal using Lazarus IDE and the Free Pascal Compiler (FPC).
    <br />
    <a href="https://github.com/ikelaiah/free-pascal-snippets"><strong>Explore the docs »</strong></a>
    <br />
  </p>
</div>



## Contents

### Code Structure

All about structuring Pascal source files.

- **ProgramStructure**. Structure of a Pascal program.
- **SimpleProgram**. An example of a Pascal program.
- **UnitStructure**. Structure of a Unit file.
- **SimpleProgramWithUnit**. An example of creating and using a unit file.

 ### Command Line Arguments

All about parsing command line arguments and options.

- **CLSimple**. Parsing arguments using `ParamStr` and `ParamCount`.
- **GetOptSimple**. An example of using `GetOpt` to parse command line flags.

### Date Time

- **DateTimeBenchmark**. A simple way to profile your program.
- **DateTimeBetween**. Finding time difference between two timestamps.
- **DateTimeComparison**. Comparing date times.
- **DateTimeCurrent**. Getting the current date time.
- **DateTimeUnix**.  Getting date time in unix notation.
- **ParseDate**.  A simple example of parsing a string into a `TDateTime` object using `ScanDateTime`.


### File Handling

All about file handling; reading and writing.

- **ClassicNewTextFile**. Create a new text file the classical way.
- **ClassicNewTextFileOrganised**. Create a new text file the classical way but more organised.
- **TFileStreamNewTextFile**. Create a text file the object way.
- **TFileStreamNewTextFileOrganised**. Create a text file the object way but more organised.
- **ClassicCreateBlankTextFile**. The classical way of creating a blank file.
- **TFileStreamCreateBlankTextFile**. The object way of creating a blank file.
- **TStreamReaderReadFile**. Read a text file using `TStreamReader`.
- **TStreadReaderReadFileTidy**. Read a text file using `TStreamReader` but more tidy.

### FuncProc

- **ParamModifierConst**. Ensuring function arguments won't be changed in a function or procedure.
- **ParamModifierVar**. Moifying named parameters from a function or procedure.


### Immutability

Ensuring `const` behaving like `const` in other programing languages.


### Lists

All about building lists in Free Pascal.

- **StaticArray**. Building and processing static arrays.
- **DynamicArray**. Building and processing dynamic arrays.
- **StringList**. Create a list of string.
- **SimpleIntegerList**. Create a list of integer using `Generics.Collections` unit and sort it.
- **TListCustomComparison**. Crete a custom comparer for a `TList<T>` list.
- **FGLIntegerList**. Create a list of integer using `fgl` unit and sort it.
- **AppendFPGList**. Append two `TFPGList<integer>` lists.
- **LGIntegerList**. Create a list of integer using `TGVector<T>` from `LGenerics` unit.
- **LGIntegerListSort**. Sort a `TGVector<integer>` list.

### Numbers

All things about numbers.

- **RandomNumberSimple**. Generate a random number, simplest way.
- **RandomNumberBetween**. Generate a random integer number between two numbers.
- **RandomRealNumberBetween**. Generate a random real number between two numbers.
- **RandomRealNumberList**. Create a list of random number using LGenerics.
- **RandomRealNumberListv2**. Create a list of random number using a dynamic array.


### Regex

Examples on using regex expressions.

- **RegexSimpleExample**. A simple pattern matching using regex.     
- **ReplaceDateSeparators**. An example of replacing date separators using regex.


<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Getting Started

### Prerequisites

Install both the [Free Pascal Compiler (FPC)](https://www.freepascal.org) and [Lazarus IDE](https://www.lazarus-ide.org). Use [`fpcupdeluxe`](https://github.com/LongDirtyAnimAlf/fpcupdeluxe).

You can find the latest installer here; [https://github.com/LongDirtyAnimAlf/fpcupdeluxe/releases](https://github.com/LongDirtyAnimAlf/fpcupdeluxe/releases).


### Installation

No installation needed. Just download or `git clone` the repo to your local drive.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

### Using Lazarus IDE

1. Launch your Lazarus IDE.
2. Top bar menu, go to `Projects` - `Open Project ...`. 
3. Navigate to the snippet folder you'd like to see, and open the `.lpi` file.

### Using your favourite text editor

1. Navigate to an example folder.
2. Open the `.lpr` file. This is the program source code.

## License

Distributed under the MIT License. See `LICENSE.md` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>


## Thanks

- The FPC devs for sharing the joy of Object Pascal.
- The Lazarus IDE devs for making such an amazing IDE.
- The people behind various units/modules in OPM.
- The lovely people at the [Unofficial Free Pascal discord server](https://discord.com/channels/570025060312547359/570091337173696513). You guys are gems.
- The fine people at the [Free Pascal & Lazarus forum](https://forum.lazarus.freepascal.org/index.php).

<p align="right">(<a href="#readme-top">back to top</a>)</p>