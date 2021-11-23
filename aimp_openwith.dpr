library aimp_openwith;

{$R *.res}
{$R *.dres}

uses
  apiPlugin,
  Plugin in 'Source\Plugin.pas',
  Menu.Manager in 'Source\Menu.Manager.pas',
  Menu.Action in 'Source\Menu.Action.pas',
  Menu.Action.Playlist in 'Source\Menu.Action.Playlist.pas',
  Menu.Action.MediaLibrary in 'Source\Menu.Action.MediaLibrary.pas',
  Settings in 'Source\Settings.pas',
  Settings.Frame in 'Source\Settings.Frame.pas',
  Settings.Form in 'Source\Settings.Form.pas',
  Utilities in 'Source\Utilities.pas';

function AIMPPluginGetHeader(out Header: IAIMPPlugin): HRESULT; stdcall;
begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF }
  try
    Header := TOpenWithPlugin.Create;
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

exports
  AIMPPluginGetHeader;

begin
end.
