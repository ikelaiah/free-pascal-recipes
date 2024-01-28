program FileHandlingObjectCreateBlankTextFile;

uses
  Classes, SysUtils;

var
  fileName: String;
  fileStream: TFileStream;

begin
  fileName := 'hello-text.txt';

  try
    // Create a new file without writing anyting into it
    fileStream := TFileStream.Create(fileName, fmCreate);
    Writeln('Created a blank file: ', fileName);
  finally
    // Free resources
    fileStream.Free;
  end;
end.

