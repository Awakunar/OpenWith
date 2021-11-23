unit Menu.Action;

interface

uses
  System.Generics.Collections,
  apiActions,
  apiObjects,
  apiThreading;

type
  TActionEventHandler = class(TInterfacedObject, IAIMPActionEvent)
  strict private
    procedure ExecuteApp(AList: TList<IAIMPString>);
    procedure ExecuteUrl(AList: TList<IAIMPString>);
  strict protected
    FItemID: string;
    function GetSelectedFilesForApp: TList<IAIMPString>; virtual; abstract;
    function GetSelectedFilesForUrl: TList<IAIMPString>; virtual; abstract;
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

  TExecuteUrlTask = class(TInterfacedObject, IAIMPTask)
  strict private
    FHandle: THandle;
    FItemID: string;
    FFiles: TList<IAIMPString>;
  public
    constructor Create(const AItemID: string; AList: TList<IAIMPString>);
    destructor Destroy; override;
  public
    procedure Execute(Owner: IAIMPTaskOwner); stdcall;
    property Handle: THandle read FHandle write FHandle;
  end;

  TSettingsMenuEventHandler = class(TInterfacedObject, IAIMPActionEvent)
  public
    procedure OnExecute(Data: IInterface); stdcall;
  end;

implementation

uses
  Plugin,
  Settings,
  Utilities,
  WinApi.ActiveX,
  System.SysUtils,
  System.IOUtils,
  System.Generics.Defaults,
  IdURI,
  apiOptions,
  apiMessages,
  apiWrappers,
  apiFileManager;

procedure TActionEventHandler.OnExecute(Data: IInterface);
var
  LAction: IAIMPAction;
begin
  if Supports(Data, IAIMPAction, LAction) then
  begin
    FItemID := PropListGetStr(LAction, AIMP_ACTION_PROPID_CUSTOM);
    if not TGlobals.Settings.ContainsKey(FItemID) then
      Exit;

    case TGlobals.Settings[FItemID].ItemType of
      App: ExecuteApp(GetSelectedFilesForApp);
      URL: ExecuteUrl(GetSelectedFilesForUrl);
    end;
  end;
end;

procedure TActionEventHandler.ExecuteApp(AList: TList<IAIMPString>);
var
  LFileName, LParameters: string;
  LFiles, LFolders: TStringBuilder;
begin
  LFiles := TStringBuilder.Create;
  LFolders := TStringBuilder.Create;
  try
    for var LCount: Integer := 0 to AList.Count - 1 do
    begin
      LFileName := IAIMPStringToString(AList[LCount]);

      if not TUtilities.ValidURL(LFileName) then
      begin
        if TFile.Exists(LFileName) then
        begin
          LFiles.AppendFormat('"%s" ', [LFileName]);
          LFolders.AppendFormat('"%s" ', [TPath.GetDirectoryName(LFileName)]);
        end;
      end
      else
        LFiles.AppendFormat('"%s" ', [LFileName]);
    end;

    if LFiles.Length <= 0 then
      Exit;

    LParameters := TGlobals.Settings[FItemID].Param.Replace('%Files%', LFiles.ToString).Replace('%Folders%', LFolders.ToString);
  finally
    FreeAndNil(AList);
    FreeAndNil(LFiles);
    FreeAndNil(LFolders);
  end;

  if LParameters.Contains('%AIMP Pause%') then
  begin
    LParameters := LParameters.Replace('%AIMP Pause%', '');
    MessageDispatcherSend(AIMP_MSG_CMD_PAUSE);
  end;

  if LParameters.Contains('%AIMP Stop%') then
  begin
    LParameters := LParameters.Replace('%AIMP Stop%', '');
    MessageDispatcherSend(AIMP_MSG_CMD_STOP);
  end;

  TUtilities.ShellExec('', TGlobals.Settings[FItemID].Path, LParameters);
end;

procedure TActionEventHandler.ExecuteUrl(AList: TList<IAIMPString>);
var
  LHandle: THandle;
  LTask: TExecuteUrlTask;
  LThreadPool: IAIMPServiceThreads;
begin
  if AList.Count <= 0 then
  begin
    FreeAndNil(AList);
    Exit;
  end;

  LTask := TExecuteUrlTask.Create(FItemID, AList);
  if CoreGetService(IID_IAIMPServiceThreads, LThreadPool) and Succeeded(LThreadPool.ExecuteInThread(LTask, LHandle)) then
  begin
    LTask.Handle := LHandle;
    TGlobals.Tasks.Add(LHandle);
  end;
end;

procedure TExecuteUrlTask.Execute(Owner: IAIMPTaskOwner);
var
  LCount: Integer;
  LTempStr, LTemplate: IAIMPString;
  LEncodedParams: string;
  LUrlParamList: TList<string>;
  LFileInfo: IAIMPFileInfo;
  LFileInfoService: IAIMPServiceFileInfo;
  LFileInfoFormatter: IAIMPServiceFileInfoFormatter;
begin
  if not CoreGetService(IID_IAIMPServiceFileInfo, LFileInfoService) or
    not CoreGetService(IID_IAIMPServiceFileInfoFormatter, LFileInfoFormatter)
  then
    Exit;

  LUrlParamList := TList<string>.Create(TIStringComparer.Ordinal);
  try
    CoreCreateObject(IID_IAIMPFileInfo, LFileInfo);
    LTemplate := MakeString(TGlobals.Settings[FItemID].Param);

    for LCount := 0 to FFiles.Count - 1 do
    begin
      if Owner.IsCanceled then
        Exit;

      LTempStr := nil;
      if Succeeded(LFileInfoService.GetFileInfoFromFileURI(FFiles[LCount], 0, LFileInfo)) and
        Succeeded(LFileInfoFormatter.Format(LTemplate, LFileInfo, 0, nil, LTempStr)) and (LTempStr.GetLength > 1) then
      begin
        LEncodedParams := TIdURI.ParamsEncode(IAIMPStringToString(LTempStr));
        if not LUrlParamList.Contains(LEncodedParams) then
          LUrlParamList.Add(LEncodedParams);
      end;
    end;

    for LCount := 0 to LUrlParamList.Count - 1 do
    begin
      if Owner.IsCanceled then
        Exit;

      TUtilities.ShellExec('OPEN', Format(TGlobals.Settings[FItemID].Path, [LUrlParamList[LCount]]));
    end;
  finally
    TGlobals.Tasks.Remove(Handle);
    FreeAndNil(LUrlParamList);
  end;
end;

constructor TExecuteUrlTask.Create(const AItemID: string; AList: TList<IAIMPString>);
begin
  FItemID := AItemID;
  FFiles := AList;
end;

destructor TExecuteUrlTask.Destroy;
begin
  FreeAndNil(FFiles);

  inherited;
end;

procedure TSettingsMenuEventHandler.OnExecute(Data: IInterface);
var
  LOptionsDialog: IAIMPServiceOptionsDialog;
begin
  if CoreGetService(IID_IAIMPServiceOptionsDialog, LOptionsDialog) then
    CheckResult(LOptionsDialog.FrameShow(TGlobals.SettingsFrame, True));
end;

end.
