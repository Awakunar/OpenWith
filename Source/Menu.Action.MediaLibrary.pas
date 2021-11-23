unit Menu.Action.MediaLibrary;

interface

uses
  Menu.Action,
  System.Generics.Collections,
  apiActions,
  apiObjects,
  apiMusicLibrary;

type
  TLibraryActionEventHandler = class(TActionEventHandler)
  strict private
    function CollapseVirtual(const AFileURI: IAIMPString; out AFileName: IAIMPString): Boolean;
    function GetSelectedFiles: IAIMPMLFileList;
  strict protected
    function GetSelectedFilesForApp: TList<IAIMPString>; override;
    function GetSelectedFilesForUrl: TList<IAIMPString>; override;
  end;

  TLibraryMenuShowEventHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

implementation

uses
  WinApi.Windows,
  System.SysUtils,
  System.Generics.Defaults,
  apiMenu,
  apiWrappers,
  apiFileManager;

function TLibraryActionEventHandler.GetSelectedFiles: IAIMPMLFileList;
var
  LMusicLibrary: IAIMPServiceMusicLibraryUI;
begin
  if CoreGetService(IID_IAIMPServiceMusicLibraryUI, LMusicLibrary) then
    Checkresult(LMusicLibrary.GetFiles(AIMPML_GETFILES_FLAGS_SELECTED, Result))
  else
    Checkresult(CoreIntf.CreateObject(IID_IAIMPMLFileList, Result));
end;

function TLibraryActionEventHandler.GetSelectedFilesForApp: TList<IAIMPString>;
var
  LIndex: Integer;
  LTempStr, LCollapsedStr, LFindStr: IAIMPString;
  LFileList: IAIMPMLFileList;
  LComparer: IComparer<IAIMPString>;
begin
  LComparer := TDelegatedComparer<IAIMPString>.Create(
    function(const Left, Right: IAIMPString): Integer
    begin
      Left.Compare(Right, Result, True);
    end);

  Result := TList<IAIMPString>.Create(LComparer);
  LFileList := GetSelectedFiles;
  LFindStr := MakeString(':');

  for var LCount: Integer := 0 to LFileList.GetCount - 1 do
    if Succeeded(LFileList.GetFileName(LCount, LTempStr)) then
    begin
      LTempStr.Find(LFindStr, LIndex, 0, 4);
      if (LIndex > 1) and CollapseVirtual(LTempStr, LCollapsedStr) and not Result.Contains(LCollapsedStr) then
        Result.Add(LCollapsedStr)
      else
        Result.Add(LTempStr);
    end;
end;

function TLibraryActionEventHandler.GetSelectedFilesForUrl: TList<IAIMPString>;
var
  LTempStr: IAIMPString;
  LFileList: IAIMPMLFileList;
begin
  Result := TList<IAIMPString>.Create;
  LFileList := GetSelectedFiles;

  for var LCount: Integer := 0 to LFileList.GetCount - 1 do
    if Succeeded(LFileList.GetFileName(LCount, LTempStr)) then
      Result.Add(LTempStr);
end;

function TLibraryActionEventHandler.CollapseVirtual(const AFileURI: IAIMPString; out AFileName: IAIMPString): Boolean;
var
  LTempStr: IAIMPString;
  LVirtualFile: IAIMPVirtualFile;
  LServiceFileInfo: IAIMPServiceFileInfo;
begin
  if CoreGetService(IID_IAIMPServiceFileInfo, LServiceFileInfo) and
    Succeeded(LServiceFileInfo.GetVirtualFile(AFileURI, 0, LVirtualFile)) and
    Succeeded(LVirtualFile.GetValueAsObject(AIMP_VIRTUALFILE_PROPID_AUDIOSOURCEFILE, IID_IAIMPString, LTempStr)) then
  begin
    AFileName := LTempStr;
    Result := FileExists(IAIMPStringToString(LTempStr));
  end
  else
    Result := False;
end;

procedure TLibraryMenuShowEventHandler.OnExecute(Data: IInterface);
var
  LFiles: IAIMPMLFileList;
  LMusicLibrary: IAIMPServiceMusicLibraryUI;
begin
  if
    CoreGetService(IID_IAIMPServiceMusicLibraryUI, LMusicLibrary) and
    Succeeded(LMusicLibrary.GetFiles(AIMPML_GETFILES_FLAGS_SELECTED, LFiles))
  then
    PropListSetInt32(Data as IAIMPMenuItem, AIMP_MENUITEM_PROPID_ENABLED, LFiles.GetCount);
end;

end.
