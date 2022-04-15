unit Plugin;

interface

uses
  Settings,
  Settings.Frame,
  System.Generics.Collections,
  apiCore,
  AIMPCustomPlugin;

type
  TOpenWithPlugin = class(TAIMPCustomPlugin)
  protected
    function InfoGet(Index: Integer): PWideChar; override; stdcall;
    function InfoGetCategories: Cardinal; override; stdcall;
    function Initialize(Core: IAIMPCore): HRESULT; override; stdcall;
    procedure Finalize; override; stdcall;
  end;

  TGlobals = class
  public
    class var Settings: TSettings;
    class var SettingsFrame: TSettingsFrame;
    class var Tasks: TList<THandle>;
  end;

implementation

uses
  Menu.Manager,
  Winapi.Windows,
  System.SysUtils,
  apiGUI,
  apiPlugin,
  apiWrappers,
  apiPlaylists,
  apiOptions,
  apiThreading;

function TOpenWithPlugin.InfoGet(Index: Integer): PWideChar;
begin
  case index of
    AIMP_PLUGIN_INFO_NAME:
      Result := 'OpenWith 1.6.1';
    AIMP_PLUGIN_INFO_AUTHOR:
      Result := 'Awakunar';
    AIMP_PLUGIN_INFO_SHORT_DESCRIPTION:
      Result := 'Open selected tracks in one of the external applications';
  else
    Result := nil;
  end;
end;

function TOpenWithPlugin.Initialize(Core: IAIMPCore): HRESULT;
var
  LMenuManager: TMenuManager;
  LServiceUI: IAIMPServiceUI;
  LPlaylistManager: IAIMPServicePlaylistManager;
  {$IFDEF DEBUG}
  LOptionsDialog: IAIMPServiceOptionsDialog;
  {$ENDIF }
begin
  Result := inherited Initialize(Core);
  if Failed(Result) or not CoreGetService(IAIMPServiceUI, LServiceUI) or
    not CoreGetService(IAIMPServicePlaylistManager, LPlaylistManager)
  then
    Exit(E_NOTIMPL);

  TGlobals.Settings := TSettings.Create;
  TGlobals.Settings.Load;

  TGlobals.Tasks := TList<THandle>.Create;
  TGlobals.SettingsFrame := TSettingsFrame.Create;
  CheckResult(Core.RegisterExtension(IID_IAIMPServiceOptionsDialog, TGlobals.SettingsFrame));

  LMenuManager := TMenuManager.Create;
  try
    LMenuManager.CreateMenu;
  finally
    FreeAndNil(LMenuManager);
  end;

  {$IFDEF DEBUG}
  if CoreGetService(IID_IAIMPServiceOptionsDialog, LOptionsDialog) then
    CheckResult(LOptionsDialog.FrameShow(TGlobals.SettingsFrame, True));
  {$ENDIF }
end;

function TOpenWithPlugin.InfoGetCategories: Cardinal;
begin
  Result := AIMP_PLUGIN_CATEGORY_ADDONS;
end;

procedure TOpenWithPlugin.Finalize;
var
  LThreadPool: IAIMPServiceThreads;
begin
  if (TGlobals.Tasks.Count > 0) and CoreGetService(IID_IAIMPServiceThreads, LThreadPool) then
    for var LCount: Integer := 0 to TGlobals.Tasks.Count - 1 do
    begin
      LThreadPool.Cancel(TGlobals.Tasks[LCount], 0);
      LThreadPool.WaitFor(TGlobals.Tasks[LCount]);
    end;

  FreeAndNil(TGlobals.Tasks);
  FreeAndNil(TGlobals.Settings);
  TGlobals.SettingsFrame := nil;
end;

end.
