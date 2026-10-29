unit Schnapsen.Net;

{ Zeilenbasierte Verbindungen zwischen Geräten: Bluetooth (RFCOMM) im Spiel,
  TCP auf 127.0.0.1 nur zum Testen mehrerer Instanzen auf einem PC (--tcp).
  Alle Callbacks kommen im Hauptthread an. }

interface

uses
  System.SysUtils, System.Classes, System.Bluetooth, System.Net.Socket;

type
  TNetLink = class
  private
    FWrite: TProc<TBytes>;
    FRead: TFunc<TBytes>;
    FClose: TProc;
    FDetached: Boolean;
    FLastRx, FLastTx: UInt64;
    procedure Deliver(const Line: string);
  public
    Seat: Integer;
    OnLine: TProc<TNetLink, string>;
    OnClosed: TProc<TNetLink>;
    constructor Create(const AWrite: TProc<TBytes>; const ARead: TFunc<TBytes>; const AClose: TProc);
    procedure Start;
    procedure Send(const Line: string);
    procedure Close;
  end;

  TNetServer = class
  private
    FStopped: Boolean;
    FStop: TProc;
  public
    procedure Stop;
  end;

const
  TcpPort = 47111;

var
  // Lebenszeichen: Links, deren Lesen mit Zeitlimit zurückkehrt (Bluetooth), senden alle
  // NetPingMs ein PING und gelten nach NetDeadMs ohne jedes empfangene Byte als getrennt.
  NetPingMs: UInt64 = 2000;
  NetDeadMs: UInt64 = 15000;

function BluetoothAvailable(out Why: string): Boolean;
function LocalPlayerName(UseTcp: Boolean): string;
type
  TPairedDevice = record
    Name, Address: string;
  end;

function PairedDevices: TArray<TPairedDevice>;
function StartServer(UseTcp: Boolean; const OnAccept: TProc<TNetLink>): TNetServer;
procedure ConnectAsync(UseTcp: Boolean; const Address: string; const Done: TProc<TNetLink, string>);
procedure EnsureBluetoothPermission(const Next, Denied: TProc);

implementation

{$IFDEF ANDROID}
uses
  System.Types, System.Permissions;
{$ENDIF}

const
  ServiceUUID: TGUID = '{6E3A5F1C-9B2D-4C8E-A1F0-3D5B7C9E2A41}';
  ServiceName = 'Bauernschnapsen';
  MaxLine = 512; // längste Protokollzeile (START mit vier Namen) ist deutlich kürzer

{ TNetLink }

// shortcut: Links werden nie freigegeben (wenige Bytes pro Verbindung), damit noch
// eingereihte Hauptthread-Aufrufe nie auf ein freigegebenes Objekt zeigen.
constructor TNetLink.Create(const AWrite: TProc<TBytes>; const ARead: TFunc<TBytes>; const AClose: TProc);
begin
  inherited Create;
  FWrite := AWrite;
  FRead := ARead;
  FClose := AClose;
  Seat := -1;
end;

procedure TNetLink.Deliver(const Line: string);
begin
  if Line = 'PING' then
    Exit;
  TThread.Queue(nil,
    procedure
    begin
      if not FDetached and Assigned(OnLine) then
        OnLine(Self, Line);
    end);
end;

procedure TNetLink.Start;
var
  T: TThread;
begin
  T := TThread.CreateAnonymousThread(
    procedure
    var
      Buf, Chunk: TBytes;
      I, Start: Integer;
    var
      Now: UInt64;
    begin
      Buf := [];
      try
        while not FDetached do
        begin
          Chunk := FRead();
          Now := TThread.GetTickCount64;
          if Length(Chunk) = 0 then
          begin
            // Zeitlimit beim Lesen: Lebenszeichen senden, stumme Gegenstelle als getrennt werten
            if Now - FLastTx >= NetPingMs then
              Send('PING');
            if Now - FLastRx > NetDeadMs then
              Abort;
            Continue;
          end;
          FLastRx := Now;
          Buf := Buf + Chunk;
          Start := 0;
          for I := 0 to High(Buf) do
            if Buf[I] = 10 then
            begin
              if I - Start > MaxLine then
                Abort; // Gegenstelle sendet Unsinn
              Deliver(TEncoding.UTF8.GetString(Buf, Start, I - Start));
              Start := I + 1;
            end;
          Buf := Copy(Buf, Start, Length(Buf) - Start);
          if Length(Buf) > MaxLine then
            Abort;
        end;
      except
        // Verbindung weg
      end;
      TThread.Queue(nil,
        procedure
        begin
          if not FDetached then
          begin
            FDetached := True;
            if Assigned(OnClosed) then
              OnClosed(Self);
          end;
        end);
    end);
  FLastRx := TThread.GetTickCount64;
  FLastTx := FLastRx;
  T.FreeOnTerminate := True;
  T.Start;
end;

procedure TNetLink.Send(const Line: string);
begin
  if FDetached then
    Exit;
  try
    // Hauptthread (Spielzüge) und Lese-Thread (PING) schreiben auf denselben Socket
    TMonitor.Enter(Self);
    try
      FWrite(TEncoding.UTF8.GetBytes(Line + #10));
      FLastTx := TThread.GetTickCount64;
    finally
      TMonitor.Exit(Self);
    end;
  except
    // nur den Socket schließen: der Lese-Thread endet dann und meldet OnClosed
    try
      FClose();
    except
    end;
  end;
end;

procedure TNetLink.Close;
begin
  if FDetached then
    Exit;
  FDetached := True;
  try
    FClose();
  except
  end;
end;

{ TNetServer }

procedure TNetServer.Stop;
begin
  FStopped := True;
  try
    FStop();
  except
  end;
end;

{ Bluetooth }

function BluetoothAvailable(out Why: string): Boolean;
begin
  Why := '';
  try
    Result := TBluetoothManager.Current.CurrentAdapter <> nil;
    if not Result then
      Why := 'Kein Bluetooth-Adapter gefunden oder Bluetooth ist ausgeschaltet.';
  except
    on E: Exception do
    begin
      Why := 'Bluetooth nicht verfügbar: ' + E.Message;
      Result := False;
    end;
  end;
end;

function LocalPlayerName(UseTcp: Boolean): string;
begin
  Result := '';
  if UseTcp then
    Result := 'Test ' + IntToStr(10 + Random(90))
  else
    try
      if TBluetoothManager.Current.CurrentAdapter <> nil then
        Result := TBluetoothManager.Current.CurrentAdapter.AdapterName;
    except
      // ohne Bluetooth bleibt der Standardname
    end;
  if Result = '' then
    Result := 'Spieler';
  Result := Copy(Result.Replace('|', ' '), 1, 16); // '|' trennt die Protokollfelder
end;

function PairedDevices: TArray<TPairedDevice>;
var
  D: TBluetoothDevice;
  P: TPairedDevice;
begin
  Result := [];
  for D in TBluetoothManager.Current.CurrentAdapter.PairedDevices do
  begin
    P.Name := D.DeviceName;
    P.Address := D.Address;
    Result := Result + [P];
  end;
end;

function LinkForBluetooth(S: TBluetoothSocket): TNetLink;
begin
  Result := TNetLink.Create(
    procedure(B: TBytes)
    begin
      S.SendData(B);
    end,
    function: TBytes
    begin
      // Leer = Zeitlimit. Connected ist bei angenommenen Sockets unter Android unzuverlässig,
      // Abbrüche erkennt der Lese-Thread über Fehler oder fehlende Lebenszeichen.
      Result := S.ReceiveData(500);
    end,
    procedure
    begin
      S.Close;
    end);
end;

function LinkForTcp(S: TSocket): TNetLink;
begin
  Result := TNetLink.Create(
    procedure(B: TBytes)
    var
      Off, N: Integer;
    begin
      Off := 0;
      while Off < Length(B) do
      begin
        N := S.Send(B, Off, Length(B) - Off); // TCP darf Teilmengen senden
        if N <= 0 then
          Abort;
        Inc(Off, N);
      end;
    end,
    function: TBytes
    var
      N: Integer;
    begin
      SetLength(Result, 1024);
      N := S.Receive(Result[0], 1024, []);
      if N <= 0 then
        Abort;
      SetLength(Result, N);
    end,
    procedure
    begin
      S.Close(True);
    end);
end;

// Eigene Funktion, damit der Link als Wert erfasst wird (die Accept-Schleife überschreibt ihre Variable).
procedure QueueAccept(Srv: TNetServer; L: TNetLink; const OnAccept: TProc<TNetLink>);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Srv.FStopped then
        L.Close
      else
        OnAccept(L);
    end);
end;

function StartServer(UseTcp: Boolean; const OnAccept: TProc<TNetLink>): TNetServer;
var
  Srv: TNetServer;
  Bt: TBluetoothServerSocket;
  Tcp: TSocket;
  T: TThread;
begin
  Srv := TNetServer.Create;
  Bt := nil;
  Tcp := nil;
  if UseTcp then
  begin
    Tcp := TSocket.Create(TSocketType.TCP);
    Tcp.Listen('127.0.0.1', '', TcpPort);
    Srv.FStop := procedure
      begin
        Tcp.Close(True);
      end;
  end
  else
  begin
    Bt := TBluetoothManager.Current.CurrentAdapter.CreateServerSocket(ServiceName, ServiceUUID, False);
    Srv.FStop := procedure
      begin
        Bt.Close;
      end;
  end;
  T := TThread.CreateAnonymousThread(
    procedure
    var
      L: TNetLink;
      BS: TBluetoothSocket;
      TS: TSocket;
    begin
      while not Srv.FStopped do
      begin
        L := nil;
        try
          if UseTcp then
          begin
            TS := Tcp.Accept(500);
            if TS <> nil then
              L := LinkForTcp(TS);
          end
          else
          begin
            BS := Bt.Accept(500);
            if BS <> nil then
              L := LinkForBluetooth(BS);
          end;
        except
          if Srv.FStopped then
            Break;
          Sleep(200);
        end;
        if L <> nil then
          QueueAccept(Srv, L, OnAccept);
      end;
    end);
  T.FreeOnTerminate := True;
  T.Start;
  Result := Srv;
end;

procedure ConnectAsync(UseTcp: Boolean; const Address: string; const Done: TProc<TNetLink, string>);
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      L: TNetLink;
      Err: string;
      D: TBluetoothDevice;
      BS: TBluetoothSocket;
      TS: TSocket;
    begin
      L := nil;
      Err := '';
      try
        if UseTcp then
        begin
          TS := TSocket.Create(TSocketType.TCP);
          TS.Connect('', '127.0.0.1', '', TcpPort);
          L := LinkForTcp(TS);
        end
        else
        begin
          for D in TBluetoothManager.Current.CurrentAdapter.PairedDevices do
            if SameText(D.Address, Address) then
            begin
              // Android: eine laufende Gerätesuche bremst oder bricht den Verbindungsaufbau ab
              TBluetoothManager.Current.CancelDiscovery;
              BS := D.CreateClientSocket(ServiceUUID, False);
              BS.Connect;
              L := LinkForBluetooth(BS);
              Break;
            end;
          if L = nil then
            Err := 'Gerät nicht gefunden.';
        end;
      except
        on E: Exception do
          Err := E.Message;
      end;
      TThread.Queue(nil,
        procedure
        begin
          Done(L, Err);
        end);
    end).Start;
end;

procedure EnsureBluetoothPermission(const Next, Denied: TProc);
begin
  {$IFDEF ANDROID}
  // Android 12+: Laufzeitrechte (zusätzlich im Manifest aktivieren). SCAN braucht schon das
  // Lesen der gekoppelten Geräte, weil der Adapter dabei isDiscovering abfragt.
  PermissionsService.RequestPermissions(['android.permission.BLUETOOTH_CONNECT', 'android.permission.BLUETOOTH_SCAN'],
    procedure(const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray)
    var
      R: TPermissionStatus;
    begin
      for R in AGrantResults do
        if R <> TPermissionStatus.Granted then
        begin
          Denied();
          Exit;
        end;
      Next();
    end);
  {$ELSE}
  Next();
  {$ENDIF}
end;

end.
