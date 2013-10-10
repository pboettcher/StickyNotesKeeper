unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Menus, TntMenus;

const
  WM_MYICONNOTIFY=WM_USER+123;

type
  TForm1 = class(TForm)
    Timer1: TTimer;
    PopupMenu1: TTntPopupMenu;
    miClipboard: TTntMenuItem;
    miSep: TTntMenuItem;
    miExit: TTntMenuItem;
    miToFront: TTntMenuItem;
    procedure Timer1Timer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure miExitClick(Sender: TObject);
    procedure miToFrontClick(Sender: TObject);
  private
    procedure WMIcon(var msg:TMessage); message WM_MYICONNOTIFY;
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses ShellAPI;

procedure Msg(Text:String);
begin
  MessageBox(0, PChar(Text), 'Sticky hider', 0);
end;

function GetWindowsDirectory(var S: String): Boolean;
var
  Len: Integer;
begin
  Len := Windows.GetWindowsDirectory(nil, 0);
  if Len > 0 then
  begin
    SetLength(S, Len);
    Len := Windows.GetWindowsDirectory(PChar(S), Len);
    SetLength(S, Len);
    Result := Len > 0;
  end else
    Result := False;
end;

function ExecNewProcess(ProgramName : String):Boolean;
var
  StartInfo  : TStartupInfo;
  ProcInfo   : TProcessInformation;
begin
  FillChar(StartInfo, SizeOf(TStartupInfo),#0);
  FillChar(ProcInfo, SizeOf(TProcessInformation),#0);
  StartInfo.cb := SizeOf(TStartupInfo);
  Result := CreateProcess(PChar(ProgramName),nil, nil, nil,False,
              CREATE_NEW_PROCESS_GROUP+NORMAL_PRIORITY_CLASS,
              nil, nil, StartInfo, ProcInfo);
end;

function GetStickyWindow(Wait:Boolean=False):HWND;
var Retries:Integer;
begin
  Retries:=0;
  repeat
    Result:=FindWindow('Sticky_Notes_Top_Window', nil);
    Sleep(100);
    Inc(Retries);
  until (Result<>0) or (Retries>50) or (not Wait);
end;

function GetStickyWindowOrRun:HWND;
var StickyExe:String;
begin
  Result:=GetStickyWindow;
  if Result=0 then begin
    GetWindowsDirectory(StickyExe);
    StickyExe:=StickyExe+'\System32\StikyNot.exe';
    if FileExists(StickyExe) then begin
      ExecNewProcess(StickyExe);
      Result:=GetStickyWindow(True);
      SetWindowPos(Result, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOSIZE or SWP_NOMOVE or SWP_NOACTIVATE);
    end;
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var hSticky:HWND;
begin
  hSticky:=GetStickyWindowOrRun;
  if hSticky=0 then Exit;
  ShowWindow(hSticky, SW_HIDE);
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
var hSticky:HWND;
begin
  hSticky:=GetStickyWindowOrRun;
  if hSticky=0 then Exit;
  SendMessage(hSticky, WM_CLOSE, 0, 0);
end;

procedure ShowStickyNotes;
var hSticky:HWND;
begin
  hSticky:=GetStickyWindowOrRun;
  if hSticky=0 then Exit;
  SetForegroundWindow(hSticky);
end;

procedure TForm1.WMIcon(var msg:TMessage);
var P:TPoint;
begin
  case msg.LParam of
    WM_RBUTTONUP:
      begin
        GetCursorPos(P);
        SetForegroundWindow(Application.MainForm.Handle);
        PopupMenu1.Popup(P.X,P.Y);
      end;
    WM_LBUTTONDOWN: ShowStickyNotes;
  end;
end;

procedure TForm1.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure CreateTrayIcon(Handle:HWND; IHandle:HWND;
  n:Integer);
var NIData:TNotifyIconData;
begin
  with NIData do begin
    cbSize:=SizeOf(TNotifyIconData);
    {HWND нашего окна (окна, принимающего обратные
     сообщения)}
    Wnd:=Handle;
    uID:=n; //номер значка
    uFlags:=NIF_ICON or NIF_MESSAGE or NIF_TIP;
    uCallBackMessage:=WM_MYICONNOTIFY; //обратное сообщение
    {то, откуда сдёргивается значок это может быть и
     ImageList и т.д.}
    hIcon:=IHandle;
    StrPCopy(szTip,'Sticky notes keeper'); //всплывающая строка
  end;
  Shell_NotifyIcon(NIM_ADD,@NIData); //добавление значка
end;

procedure DeleteTrayIcon(Handle:HWND; n:Integer);
var NIData:TNotifyIconData;
begin
  with NIData do begin
    cbSize:=SizeOf(TNotifyIconData);
    Wnd:=Handle;
    uID:=n;
  end;
  Shell_NotifyIcon(NIM_DELETE,@NIData); //удаление значка
end;

constructor TForm1.Create(AOwner:TComponent);
begin
  inherited Create(AOwner);
  CreateTrayIcon(Handle,Application.Icon.Handle,0);
end;

destructor TForm1.Destroy;
begin
  DeleteTrayIcon(Handle,0);
  inherited Destroy;
end;

procedure TForm1.miToFrontClick(Sender: TObject);
begin
  ShowStickyNotes;
end;

end.

