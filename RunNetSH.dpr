program RunNetSH;

uses
  System.SysUtils,
  System.IniFiles,
  Winapi.ShellAPI,
  Winapi.Windows,
  Winapi.Messages,
  Winapi.WinSock,
  Winapi.IpHlpApi,
  Vcl.Forms,
  System.Notification;

{$R *.res}

procedure RunNetSHProxy(ListenAddress, ListenPort, ConnectAddress, ConnectPort: string);
var
  Command: string;
  SEI: TShellExecuteInfo;
begin
  Command := Format(
    'netsh interface portproxy add v4tov4 listenaddress=%s listenport=%s connectaddress=%s connectport=%s',
    [ListenAddress, ListenPort, ConnectAddress, ConnectPort]
  );

  ZeroMemory(@SEI, SizeOf(SEI));
  SEI.cbSize := SizeOf(TShellExecuteInfo);
  SEI.Wnd := 0;
  SEI.fMask := SEE_MASK_FLAG_DDEWAIT or SEE_MASK_FLAG_NO_UI;
  SEI.lpVerb := 'runas';
  SEI.lpFile := 'cmd.exe';
  SEI.lpParameters := PChar('/C ' + Command);
  SEI.nShow := SW_HIDE;

  if not ShellExecuteEx(@SEI) then
    RaiseLastOSError;
end;

function DeleteNetSHProxy(ListenAddress, ListenPort: string): Boolean;
var
  Command: string;
  SEI: TShellExecuteInfo;
begin
  Command := Format(
    'netsh interface portproxy delete v4tov4 listenaddress=%s listenport=%s',
    [ListenAddress, ListenPort]
  );

  ZeroMemory(@SEI, SizeOf(SEI));
  SEI.cbSize := SizeOf(TShellExecuteInfo);
  SEI.Wnd := 0;
  SEI.fMask := SEE_MASK_FLAG_DDEWAIT or SEE_MASK_FLAG_NO_UI;
  SEI.lpVerb := 'runas';
  SEI.lpFile := 'cmd.exe';
  SEI.lpParameters := PChar('/C ' + Command);
  SEI.nShow := SW_HIDE;

  Result := ShellExecuteEx(@SEI);
end;

function ResolveHostname(const Hostname: string): string;
var
  WSAData: TWSAData;
  HostEnt: PHostEnt;
  Addr: PInAddr;
begin
  Result := '';
  WSAStartup($0202, WSAData);
  try
    HostEnt := gethostbyname(PAnsiChar(AnsiString(Hostname)));
    if Assigned(HostEnt) then
    begin
      Addr := PInAddr(HostEnt^.h_addr_list^);
      Result := string(inet_ntoa(Addr^));
    end;
  finally
    WSACleanup;
  end;
end;

function IsAnotherInstanceRunning(const MutexName: string): Boolean;
begin
  Result := CreateMutex(nil, False, PChar(MutexName)) = 0;
  if not Result then
    Result := GetLastError = ERROR_ALREADY_EXISTS;
end;

procedure MonitorNetworkChanges(var StopFlag: Boolean);
var
  AddrChangeHandle: THandle;
  Overlapped: _OVERLAPPED;
  WaitResult: DWORD;
begin
  ZeroMemory(@Overlapped, SizeOf(OVERLAPPED));
  AddrChangeHandle := 0;

  while not StopFlag do
  begin
    if NotifyAddrChange(AddrChangeHandle, @Overlapped) = ERROR_IO_PENDING then
    begin
      WaitResult := WaitForSingleObject(AddrChangeHandle, INFINITE);
      if WaitResult = WAIT_OBJECT_0 then
      begin
        // Network change detected
        Exit;
      end;
    end else
    begin
      // Error in NotifyAddrChange
      Sleep(1000); // Wait before retrying
    end;
  end;
end;

procedure RunNetSHConfiguration(const ListenAddress, ListenPort, ConnectAddress, ConnectPort: string);
begin
  // Remove previous portproxy entries
  DeleteNetSHProxy(ListenAddress, ListenPort);
  DeleteNetSHProxy(ConnectAddress, ConnectPort);

  // Add new portproxy entries
  RunNetSHProxy(ListenAddress, ListenPort, ConnectAddress, ConnectPort);
  RunNetSHProxy(ConnectAddress, ConnectPort, ListenAddress, ListenPort);
end;

procedure ShowNotification(const NotificationCenter: TNotificationCenter; const Title: string; const Body: string);
var
  Notification: TNotification;
begin
  Notification := NotificationCenter.CreateNotification;
  try
    Notification.Name := 'RunNetSH' + Chr(ord('a') + Random(20));
    Notification.Title :=Title;
    Notification.AlertBody := Body;

    NotificationCenter.PresentNotification(Notification);
  finally
    Notification.Free;
  end;
end;

var
  IniFile: TIniFile;
  IniFilePath: string;
  ListenAddress, ListenPort, ConnectAddress, ConnectPort: string;
  HostName, ResolvedIP, OldIP: string;
  MutexName: string;
  StopFlag: Boolean;
  NotificationCenter: TNotificationCenter;
begin
  // Initialize the Application object (Needed for the Notification Center)
  Application.Initialize;
  Application.MainFormOnTaskbar := False;
  Application.Title := 'RunNetSH';

  // Implement single-instance application
  MutexName := 'RunNetSH_Mutex';
  if IsAnotherInstanceRunning(MutexName) then
  begin
    // Another instance is running, exit
    Exit;
  end;

  // Create a new Notification Center instance
  NotificationCenter := TNotificationCenter.Create(Application);
  try
    // Load initial settings
    IniFilePath := ExtractFilePath(ParamStr(0)) + 'config.ini';
    IniFile := TIniFile.Create(IniFilePath);
    try
      ListenAddress  := IniFile.ReadString('Settings', 'ListenAddress',  '127.0.0.1');
      ListenPort     := IniFile.ReadString('Settings', 'ListenPort',     '3010');
      ConnectAddress := IniFile.ReadString('Settings', 'ConnectAddress', '192.168.90.110');
      ConnectPort    := IniFile.ReadString('Settings', 'ConnectPort',    '3010');
      HostName       := IniFile.ReadString('Settings', 'HostName',       '');
    finally
      IniFile.Free;
    end;

    OldIP := '';
    StopFlag := False;

    repeat
      // Resolve hostname
      if HostName <> '' then
        ResolvedIP := ResolveHostname(HostName)
      else
        ResolvedIP := ConnectAddress;

      if ResolvedIP = '' then
        ResolvedIP := ConnectAddress; // Fallback

      if ResolvedIP <> OldIP then
      begin
        // Run the NetSH confifuration
        RunNetSHConfiguration(ListenAddress, ListenPort, ResolvedIP, ConnectPort);
        // Update the "old" ip
        OldIP := ResolvedIP;
        // Show a notification that the config changed
        ShowNotification(NotificationCenter, 'RunNetSH', 'NetSH configuration updated with IP: ' + ResolvedIP);
      end;

      // Wait for network change notification
      MonitorNetworkChanges(StopFlag);

    until StopFlag;
  finally
    NotificationCenter.free;
  end;
end.

