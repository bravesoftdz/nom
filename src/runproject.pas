unit RunProject;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF UNIX}
  cmem,{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils,
  Process, Crt, ProjectInfo, LCLIntf;

function runServer( RunLocation: String; OpenOnReady: Boolean ):Boolean;

const
  BUF_SIZE = 2048; // Buffer size for reading the output in chunks

var
  IsBusy : Boolean;
  AProcess     : TProcess;
  OutputStream : TStream;
  BytesRead    : longint;
  Buffer       : array[1..BUF_SIZE] of byte;
  RunPort      : String;
  MaxMem       : String;

implementation

function LStreamReadChunk(const AStream: TStream): String;
  var
    LBuffer: array[byte] of Char;
  begin
    LBuffer[0] := #0;
    SetString(Result, LBuffer, AStream.Read(LBuffer, SizeOf(LBuffer)));
  end;

function runServer( RunLocation: String; OpenOnReady: Boolean ): Boolean;
var
  sl: TStringList;
  tmp: String;
  HasNotifiedStarted: Boolean;
  Key: Char;
begin
  HasNotifiedStarted := false;
  AProcess := TProcess.Create(nil);
  sl := TStringList.create;
  RunPort := GetRunPort('');
  MaxMem := GetMaxMem('');

  WriteLn( 'Starting server' );
  WriteLn( ' ' );

  {$IFDEF UNIX}
    AProcess.Executable := '/usr/bin/java';
  {$ENDIF}
  {$IFDEF WINDOWS}
    AProcess.Executable := 'java';
  {$ENDIF}
  //AProcess.CommandLine := 'java -DSTOP.PORT=11223 -DSTOP.KEY=kill_jtty -jar jetty-runner.jar --port 8099 --path / .';
  AProcess.Parameters.add('-Xmx' + MaxMem + 'm');
  AProcess.Parameters.add('-jar');
  //AProcess.Parameters.add('-DSTOP.PORT=11223');
  //AProcess.Parameters.add('-DSTOP.KEY=kill_jtty');
  AProcess.Parameters.add(RunLocation + 'jetty-runner.jar');
  AProcess.Parameters.add('--port');
  AProcess.Parameters.add(RunPort);
  AProcess.Parameters.add('--path');
  AProcess.Parameters.add('/');
  AProcess.Parameters.add('.');
  AProcess.Options := [poUsePipes, poStderrToOutPut];

  try
    AProcess.Execute;

    repeat
      if KeyPressed then begin
        Key := ReadKey;

        Case Key Of
          #111 : Begin
            OpenURL('http://localhost:' + RunPort);
          End;

          ^C : Begin
            WriteLn('');
            WriteLn('Stopping server');
            AProcess.Terminate(0);
          End;
        end;
      end;

      if AProcess.Output.NumBytesAvailable > 0 then
        begin
          sl.LoadFromStream(AProcess.Output);
          //WriteLn( sl.Text );
          for tmp in sl do
          begin
            if trim(tmp) <> '' then
              WriteLn( tmp );

            if HasNotifiedStarted = false then
              if pos('oejs.Server:main: Started @', tmp) > 0 then
                begin
                  HasNotifiedStarted := true;
                  WriteLn(' ');
                  WriteLn('Server is ready on port ' + RunPort);
                  WriteLn(' ');

                  if OpenOnReady then
                    OpenURL('http://localhost:' + RunPort)
                  else
                    WriteLn('Open browser by pressing ''o'' (as in open)');

                  WriteLn('Stop by pressing CTRL + C');
                end;
          end;
        end;
    until not AProcess.Running;
  finally
    AProcess.Free;
  end;

  WriteLn('Server stopped');

  runServer := True;
end;

end.

