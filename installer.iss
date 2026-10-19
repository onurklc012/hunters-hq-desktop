; Hunters HQ Windows installer (Inno Setup 6). Built by build.ps1, which passes:
;   /DAppVersion=1.0.0  /DDistDir=<PyInstaller one-folder output>  /O<output folder>
; Per-user install (no admin): %LOCALAPPDATA%\Programs\Hunters HQ, Start menu + optional desktop shortcut,
; uninstaller in Settings → Apps. The login / window data lives in %LOCALAPPDATA%\HuntersHQ.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef DistDir
  #error DistDir must point at PyInstaller's dist\HuntersHQ folder
#endif

[Setup]
AppId={{6B1E5B0A-4C1D-4E59-9A0B-101A0E5C0A01}
AppName=Hunters HQ
AppVersion={#AppVersion}
AppVerName=Hunters HQ {#AppVersion}
AppPublisher=101st Hunter Squadron
AppPublisherURL=https://101huntersqn.com
AppSupportURL=https://hq.101huntersqn.com
VersionInfoVersion={#AppVersion}
VersionInfoProductName=Hunters HQ
VersionInfoProductVersion={#AppVersion}
VersionInfoCompany=101st Hunter Squadron
VersionInfoDescription=Hunters HQ Setup
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\Hunters HQ
DefaultGroupName=Hunters HQ
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
OutputBaseFilename=HuntersHQ-Setup
SetupIconFile=assets\hunters-hq.ico
UninstallDisplayIcon={app}\HuntersHQ.exe
UninstallDisplayName=Hunters HQ
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
; the app holds this mutex while open: setup / uninstall ask to close it first
AppMutex=Local\HuntersHQ.MemberApp
CloseApplications=yes
#ifdef Sign
; build.ps1 defines the hqsign tool (sign.ps1) when HQ_SIGN_THUMBPRINT is set
SignTool=hqsign
SignedUninstaller=yes
#endif

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
turkish.NoWebView2=Hunters HQ, Windows'un "Microsoft Edge WebView2 Runtime" bileşenine ihtiyaç duyar ve bu bilgisayarda bulunamadı.%n%nMicrosoft'un resmi WebView2 indirme bağlantısı şimdi açılsın mı? (Kurulum devam edecek; WebView2'yi kurduktan sonra Hunters HQ'yu açın.)
english.NoWebView2=Hunters HQ needs Windows' "Microsoft Edge WebView2 Runtime", which is not installed on this PC.%n%nOpen Microsoft's official WebView2 download now? (Setup continues; open Hunters HQ after installing WebView2.)
turkish.RemoveData=Hunters HQ'nun bu bilgisayardaki giriş bilgileri ve pencere ayarları da silinsin mi?%n(Hayır derseniz yeniden kurduğunuzda giriş yapmanız gerekmez.)
english.RemoveData=Also remove Hunters HQ's saved login and window settings from this PC?%n(Choose No to stay logged in if you reinstall.)

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; a new version replaces the whole bundle (no stale DLLs from an older build)
Type: filesandordirs; Name: "{app}\_internal"

[Icons]
Name: "{autoprograms}\Hunters HQ"; Filename: "{app}\HuntersHQ.exe"; AppUserModelID: "HuntersSQN.HuntersHQ.Member"; Comment: "101st Hunter Squadron - Hunters HQ"
Name: "{autodesktop}\Hunters HQ"; Filename: "{app}\HuntersHQ.exe"; AppUserModelID: "HuntersSQN.HuntersHQ.Member"; Comment: "101st Hunter Squadron - Hunters HQ"; Tasks: desktopicon

[Run]
Filename: "{app}\HuntersHQ.exe"; Description: "{cm:LaunchProgram,Hunters HQ}"; Flags: nowait postinstall skipifsilent

[Code]
const
  WebView2Client = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
  WebView2Download = 'https://go.microsoft.com/fwlink/p/?LinkId=2124703';

function HasWebView2(): Boolean;
var
  pv: String;
begin
  Result :=
    (RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\' + WebView2Client, 'pv', pv) and (pv <> '') and (pv <> '0.0.0.0')) or
    (RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\' + WebView2Client, 'pv', pv) and (pv <> '') and (pv <> '0.0.0.0')) or
    (RegQueryStringValue(HKCU, 'SOFTWARE\Microsoft\EdgeUpdate\Clients\' + WebView2Client, 'pv', pv) and (pv <> '') and (pv <> '0.0.0.0'));
end;

function InitializeSetup(): Boolean;
var
  code: Integer;
begin
  Result := True;
  if not HasWebView2() and not WizardSilent() then
    if MsgBox(CustomMessage('NoWebView2'), mbConfirmation, MB_YESNO) = IDYES then
      ShellExec('open', WebView2Download, '', '', SW_SHOWNORMAL, ewNoWait, code);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if (CurUninstallStep = usPostUninstall) and not UninstallSilent() then
    if MsgBox(CustomMessage('RemoveData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      DelTree(ExpandConstant('{localappdata}\HuntersHQ'), True, True, True);
end;
