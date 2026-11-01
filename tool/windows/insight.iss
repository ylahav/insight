; Windows installer for the Insight tools.
; Build the stage folder first: tool\package_windows.ps1
; Then this script, which that same command runs when Inno Setup is installed.

#define MyAppName "Insight for Flutter"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "Yair Lahav"
#define MyAppURL "https://github.com/ylahav/insight"

[Setup]
AppId={{7F3C1A9E-4B62-4D8A-9C15-2E6A8B0D4F31}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\Insight
DefaultGroupName=Insight
DisableProgramGroupPage=yes
LicenseFile=..\..\LICENSE
OutputDir=..\..\dist\windows
OutputBaseFilename=Insight-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
ChangesEnvironment=yes
UninstallDisplayIcon={app}\analyzer\analyzer.exe
SetupIconFile=..\analyzer\windows\runner\resources\app_icon.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Add an Analyzer icon to the desktop"; GroupDescription: "Additional icons:"

[Files]
Source: "..\..\dist\windows\stage\analyzer\*"; DestDir: "{app}\analyzer"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\dist\windows\stage\bin\*"; DestDir: "{app}\bin"; Flags: ignoreversion

[Icons]
Name: "{group}\Analyzer"; Filename: "{app}\analyzer\analyzer.exe"
Name: "{autodesktop}\Analyzer"; Filename: "{app}\analyzer\analyzer.exe"; Tasks: desktopicon

[Code]
const
  EnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

function ReplacePath(const Paths, Path: string): string;
var
  Rest, Item, Built: string;
  Separator: Integer;
begin
  Rest := Paths;
  Built := '';
  while Rest <> '' do
  begin
    Separator := Pos(';', Rest);
    if Separator = 0 then
    begin
      Item := Rest;
      Rest := '';
    end
    else
    begin
      Item := Copy(Rest, 1, Separator - 1);
      Rest := Copy(Rest, Separator + 1, Length(Rest));
    end;
    if (Item <> '') and (CompareText(Item, Path) <> 0) then
    begin
      if Built <> '' then
        Built := Built + ';';
      Built := Built + Item;
    end;
  end;
  Result := Built;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Paths, Bin: string;
begin
  if CurStep <> ssPostInstall then
    exit;
  Bin := ExpandConstant('{app}\bin');
  if not RegQueryStringValue(HKLM, EnvironmentKey, 'Path', Paths) then
    Paths := '';
  if Pos(';' + Uppercase(Bin) + ';', ';' + Uppercase(Paths) + ';') = 0 then
  begin
    if (Paths <> '') and (Paths[Length(Paths)] <> ';') then
      Paths := Paths + ';';
    Paths := Paths + Bin;
    RegWriteExpandStringValue(HKLM, EnvironmentKey, 'Path', Paths);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Paths, Bin: string;
begin
  if CurUninstallStep <> usPostUninstall then
    exit;
  Bin := ExpandConstant('{app}\bin');
  if not RegQueryStringValue(HKLM, EnvironmentKey, 'Path', Paths) then
    exit;
  RegWriteExpandStringValue(HKLM, EnvironmentKey, 'Path', ReplacePath(Paths, Bin));
end;
