unit Menu.Action.Playlist;

interface

uses
  Menu.Action,
  System.Generics.Collections,
  apiActions,
  apiObjects;

type
  TPlaylistActionEventHandler = class(TActionEventHandler)
  strict private
    procedure ExecuteRadioInUrl;
    function GetSelectedFiles(ACollapseVirtual: Boolean): IAIMPObjectList;
  strict protected
    function GetSelectedFilesForApp: TList<IAIMPString>; override;
    function GetSelectedFilesForUrl: TList<IAIMPString>; override;
  end;

  TPlaylistMenuShowEventHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

implementation

uses
  Plugin,
  Utilities,
  WinApi.Windows,
  System.SysUtils,
  IdURI,
  apiMenu,
  apiWrappers,
  apiPlaylists,
  apiFileManager;

function TPlaylistActionEventHandler.GetSelectedFiles(ACollapseVirtual: Boolean): IAIMPObjectList;
var
  LPlaylist: IAIMPPlaylist;
  LPlaylistManager: IAIMPServicePlaylistManager;
  LFlags: Cardinal;
begin
  CoreIntf.CreateObject(IID_IAIMPObjectList, Result);
  if CoreGetService(IID_IAIMPServicePlaylistManager, LPlaylistManager) and Succeeded(LPlaylistManager.GetActivePlaylist(LPlaylist))
  then
  begin
    LFlags := AIMP_PLAYLIST_GETFILES_FLAGS_SELECTED_ONLY;
    if ACollapseVirtual then
      LFlags := LFlags + AIMP_PLAYLIST_GETFILES_FLAGS_COLLAPSE_VIRTUAL;

    CheckResult(LPlaylist.GetFiles(LFlags, Result));
  end;
end;

function TPlaylistActionEventHandler.GetSelectedFilesForApp: TList<IAIMPString>;
var
  LTempStr: IAIMPString;
  LFileList: IAIMPObjectList;
begin
  Result := TList<IAIMPString>.Create;
  LFileList := GetSelectedFiles(True);

  for var LCount: Integer := 0 to LFileList.GetCount - 1 do
    if Succeeded(LFileList.GetObject(LCount, IID_IAIMPString, LTempStr)) then
      Result.Add(LTempStr)
end;

function TPlaylistActionEventHandler.GetSelectedFilesForUrl: TList<IAIMPString>;
var
  LTempStr: IAIMPString;
  LFileList: IAIMPObjectList;
  LHasRadio: Boolean;
begin
  LHasRadio := False;
  Result := TList<IAIMPString>.Create;
  LFileList := GetSelectedFiles(False);

  for var LCount: Integer := 0 to LFileList.GetCount - 1 do
    if Succeeded(LFileList.GetObject(LCount, IID_IAIMPString, LTempStr)) then
      if not TUtilities.ValidURL(IAIMPStringToString(LTempStr)) then
        Result.Add(LTempStr)
      else
        LHasRadio := True;

  // Костыль на отрытие радиостанций в URL
  if LHasRadio then
    ExecuteRadioInUrl;
end;

procedure TPlaylistActionEventHandler.ExecuteRadioInUrl;
var
  LTempStr, LTemplate: IAIMPString;
  LPlaylist: IAIMPPlaylist;
  LPlaylistItem: IAIMPPlaylistItem;
  LPlaylistManager: IAIMPServicePlaylistManager;
  LFileInfo: IAIMPFileInfo;
  LFileInfoFormatter: IAIMPServiceFileInfoFormatter;
begin
  if
    CoreGetService(IID_IAIMPServiceFileInfoFormatter, LFileInfoFormatter) and
    CoreGetService(IID_IAIMPServicePlaylistManager, LPlaylistManager) and
    Succeeded(LPlaylistManager.GetActivePlaylist(LPlaylist))
  then
  begin
    LTemplate := MakeString(TGlobals.Settings[FItemID].Param);

    for var LCount: Integer := 0 to LPlaylist.GetItemCount - 1 do
    begin
      if
        Succeeded(LPlaylist.GetItem(LCount, IID_IAIMPPlaylistItem, LPlaylistItem)) and
        (PropListGetInt32(LPlaylistItem, AIMP_PLAYLISTITEM_PROPID_SELECTED) <> 0) and
        TUtilities.ValidURL(PropListGetStr(LPlaylistItem, AIMP_PLAYLISTITEM_PROPID_FILENAME))
      then
      begin
        LPlaylistItem.GetValueAsObject(AIMP_PLAYLISTITEM_PROPID_FILEINFO, IID_IAIMPFileInfo, LFileInfo);
        LFileInfoFormatter.Format(LTemplate, LFileInfo, 0, nil, LTempStr);
        if LTempStr.GetLength > 1 then
          TUtilities.ShellExec(
            'OPEN', Format(TGlobals.Settings[FItemID].Path, [TIdURI.ParamsEncode(IAIMPStringToString(LTempStr))]));
      end;
    end;
  end;
end;

procedure TPlaylistMenuShowEventHandler.OnExecute(Data: IInterface);
var
  LFiles: IAIMPObjectList;
  LPlaylist: IAIMPPlaylist;
  LPlaylistManager: IAIMPServicePlaylistManager;
begin
  if
    CoreGetService(IID_IAIMPServicePlaylistManager, LPlaylistManager) and
    Succeeded(LPlaylistManager.GetActivePlaylist(LPlaylist)) and
    Succeeded(CoreIntf.CreateObject(IID_IAIMPObjectList, LFiles)) and
    Succeeded(LPlaylist.GetFiles(AIMP_PLAYLIST_GETFILES_FLAGS_SELECTED_ONLY, LFiles))
  then
    PropListSetInt32(Data as IAIMPMenuItem, AIMP_MENUITEM_PROPID_ENABLED, LFiles.GetCount);
end;

end.
