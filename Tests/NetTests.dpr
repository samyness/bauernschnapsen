program NetTests;

{$APPTYPE CONSOLE}

// Prüft die TCP-Variante der Verbindungsschicht: Server, Client, Zeilen in beide Richtungen, Trennung.

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  Schnapsen.Net in '..\Schnapsen.Net.pas';

var
  Got: TStringList;
  Srv: TNetServer;
  ClientLink, ServerLink: TNetLink;
  T0: Cardinal;

procedure Pump(Ms: Cardinal);
begin
  T0 := TThread.GetTickCount;
  while TThread.GetTickCount - T0 < Ms do
    CheckSynchronize(20);
end;

// Simulierte Funkverbindung wie Bluetooth: Lesen kehrt nach Zeitlimit leer zurück.
// Eine stille, aber lebende Verbindung darf nicht als getrennt gelten; eine stumme schon.
procedure HeartbeatTest;
var
  AtoB, BtoA: TThreadedQueue<TBytes>;
  A, B: TNetLink;
  ADead, BClosed, AClosed: Boolean;
  BGot: TStringList;

  function Pipe(const Outq, Inq: TThreadedQueue<TBytes>; IsA: Boolean): TNetLink;
  begin
    Result := TNetLink.Create(
      procedure(Bytes: TBytes)
      begin
        if not (IsA and ADead) then
          Outq.PushItem(Bytes);
      end,
      function: TBytes
      begin
        if Inq.PopItem(Result) <> wrSignaled then
          Result := [];
      end,
      procedure
      begin
      end);
  end;

begin
  NetPingMs := 200;
  NetDeadMs := 1500;
  AtoB := TThreadedQueue<TBytes>.Create(1000, 100, 100);
  BtoA := TThreadedQueue<TBytes>.Create(1000, 100, 100);
  BGot := TStringList.Create;
  ADead := False;
  AClosed := False;
  BClosed := False;
  A := Pipe(AtoB, BtoA, True);
  B := Pipe(BtoA, AtoB, False);
  A.OnClosed := procedure(X: TNetLink) begin AClosed := True; end;
  B.OnClosed := procedure(X: TNetLink) begin BClosed := True; end;
  B.OnLine := procedure(X: TNetLink; S: string) begin BGot.Add(S); end;
  A.Start;
  B.Start;
  Pump(3000); // doppelt so lang wie NetDeadMs, ohne Spielnachrichten
  if AClosed or BClosed then
    raise Exception.Create('FEHLER: stille Verbindung wurde als getrennt gewertet');
  A.Send('hallo');
  Pump(500);
  if BGot.Text <> 'hallo' + sLineBreak then
    raise Exception.Create('FEHLER: PING landete im Spiel oder Nachricht fehlt: ' + BGot.CommaText);
  ADead := True; // A verstummt
  Pump(2500);
  if not BClosed then
    raise Exception.Create('FEHLER: stumme Gegenstelle nicht erkannt');
  A.Close;
  Writeln('Lebenszeichen OK');
end;

begin
  Got := TStringList.Create;
  try
    HeartbeatTest;
    Srv := StartServer(True,
      procedure(L: TNetLink)
      begin
        ServerLink := L;
        L.OnLine := procedure(X: TNetLink; S: string)
          begin
            Got.Add('S<' + S);
            X.Send('pong ' + S);
          end;
        L.OnClosed := procedure(X: TNetLink)
          begin
            Got.Add('S closed');
          end;
        L.Start;
      end);
    ConnectAsync(True, '',
      procedure(L: TNetLink; Err: string)
      begin
        if L = nil then
        begin
          Got.Add('connect failed: ' + Err);
          Exit;
        end;
        ClientLink := L;
        L.OnLine := procedure(X: TNetLink; S: string)
          begin
            Got.Add('C<' + S);
          end;
        L.Start;
        L.Send('HELLO|1|Test');
        L.Send('zwei');
      end);
    Pump(2000);
    Writeln('server link: ', ServerLink <> nil, '  client link: ', ClientLink <> nil);
    if ClientLink <> nil then
      ClientLink.Close;
    Pump(1500);
    Srv.Stop;
    Writeln(Got.Text);
    if Got.IndexOf('C<pong zwei') < 0 then
    begin
      Writeln('FEHLER');
      ExitCode := 1;
    end
    else
      Writeln('Net OK');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
