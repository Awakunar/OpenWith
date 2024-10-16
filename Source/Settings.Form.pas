unit Settings.Form;

interface

uses
  Settings,
  Winapi.Windows,
  System.Classes,
  System.Generics.Collections,
  apiGUI,
  apiActions,
  apiObjects;

const
  NullRect: TRect = (Left: 0; Top: 0; Right: 0; Bottom: 0);

type
  TSettingItemEx = class(TSettingItem)
  strict private
    FIcon: IAIMPImage;
  public
    constructor Create(const ATitle, APath, AParam: string; AType: TItemType; AImage: IAIMPImage);
  public
    property Icon: IAIMPImage read FIcon write FIcon;
  end;

  TSettingsForm = class(
    TInterfacedObject,
    IAIMPActionEvent,
    IAIMPUIChangeEvents,
    IAIMPUIFormEvents,
    IAIMPUIFormEvents3,
    IAIMPUITreeListEvents,
    IAIMPUITreeListCustomDrawEvents)
  private
    FForm: IAIMPUIForm;
    FService: IAIMPServiceUI;
    FTreeListPrograms: IAIMPUITreeList;
    FButtonAdd: IAIMPUIButton;
    FButtonDelete: IAIMPUIButton;
    FDropDownMenuAdd: IAIMPUIPopupMenu;
    FImageList: IAIMPUIImageList;
    FEditPath: IAIMPUIEdit;
    FEditTitle: IAIMPUIEdit;
    FEditParams: IAIMPUIEdit;
    FPopupMenuParams: IAIMPUIPopupMenu;
    FLabelPath: IAIMPUILabel;
    FLabelTitle: IAIMPUILabel;
    FLabelParams: IAIMPUILabel;
    // IAIMPUIChangeEvents
    procedure OnChanged(Sender: IInterface); stdcall;
    // IAIMPActionEvent
    procedure OnExecute(Data: IInterface); stdcall;
    // IAIMPUIFormEvents
    procedure OnActivated(Sender: IAIMPUIForm); overload; stdcall;
    procedure OnCloseQuery(Sender: IAIMPUIForm; var CanClose: LongBool); stdcall;
    procedure OnCreated(Sender: IAIMPUIForm); stdcall;
    procedure OnDeactivated(Sender: IAIMPUIForm); stdcall;
    procedure OnDestroyed(Sender: IAIMPUIForm); stdcall;
    procedure OnLocalize(Sender: IAIMPUIForm); stdcall;
    procedure OnShortCut(Sender: IAIMPUIForm; Key: Word; Modifiers: Word; var Handled: LongBool); stdcall;
    // IAIMPUIFormEvents3
    procedure OnStyleChanged(Sender: IAIMPUIForm; Style: Integer); stdcall;
    // IAIMPUITreeListEvents
    procedure OnColumnClick(Sender: IAIMPUITreeList; ColumnIndex: Integer); stdcall;
    procedure OnFocusedColumnChanged(Sender: IAIMPUITreeList); stdcall;
    procedure OnFocusedNodeChanged(Sender: IAIMPUITreeList); stdcall;
    procedure OnNodeChecked(Sender: IAIMPUITreeList; Node: IAIMPUITreeListNode); stdcall;
    procedure OnNodeDblClicked(Sender: IAIMPUITreeList; Node: IAIMPUITreeListNode); stdcall;
    procedure OnSelectionChanged(Sender: IAIMPUITreeList); stdcall;
    procedure OnSorted(Sender: IAIMPUITreeList); stdcall;
    procedure OnStructChanged(Sender: IAIMPUITreeList); stdcall;
    // IAIMPUITreeListCustomDrawEvents
    procedure OnCustomDrawNode(Sender: IAIMPUITreeList; DC: HDC; R: TRect; Node: IAIMPUITreeListNode;
      var Handled: LongBool); stdcall;
    procedure OnCustomDrawNodeCell(Sender: IAIMPUITreeList; DC: HDC; R: TRect; Node: IAIMPUITreeListNode;
      Column: IAIMPUITreeListColumn; var Handled: LongBool); stdcall;
    procedure OnGetNodeBackground(Sender: IAIMPUITreeList; Node: IAIMPUITreeListNode; var Color: DWORD); stdcall;
  private
    FSettingsList: TObjectDictionary<string, TSettingItemEx>;
    FOnModified: TNotifyEvent;
    FModified: Boolean;
    FUIStyleLight: Boolean;
    FSelectedNodeID, FPathLangStr, FParamLangStr: string;
    procedure DoModified;
    procedure OnPathButtonClick(const Sender: IUnknown);
    procedure OnURLButtonClick(const Sender: IUnknown);
    procedure OnParamsButtonClick(const Sender: IUnknown);
    procedure OnPopupItemClick(const Sender: IUnknown);
    procedure OnLabelMouseClick(const Sender: IUnknown; Button: TAIMPUIMouseButton; Shift: TShiftState; X, Y: Integer);

    procedure CreateProgsList(AParent: IAIMPUIWinControl);
    procedure CreateEditor(AParent: IAIMPUIWinControl);
    procedure CreateImport(AParent: IAIMPUIWinControl);

    function GetAppTitle(const FileName: string): string;
    procedure AddNodeToTreeList(const ID: string; Focused: Boolean = False);
  public
    constructor Create(Parent: HWND; AService: IAIMPServiceUI);
    procedure ApplyLocalization;
    procedure ConfigLoad;
    procedure ConfigSave;
    property OnModified: TNotifyEvent read FOnModified write FOnModified;
    property Form: IAIMPUIForm read FForm write FForm;
  end;

implementation

uses
  Plugin,
  Utilities,
  Menu.Manager,
  System.UITypes,
  System.Types,
  System.TypInfo,
  System.IOUtils,
  System.StrUtils,
  System.SysUtils,
  Vcl.Graphics,
  apiCore,
  apiMenu,
  apiWrappers,
  apiWrappersGUI,
  apiFileManager,
  Neon.Core.Types,
  Neon.Core.Persistence,
  Neon.Core.Persistence.JSON;

constructor TSettingItemEx.Create(const ATitle, APath, AParam: string; AType: TItemType; AImage: IAIMPImage);
begin
  inherited Create(ATitle, APath, AParam, 0, AType, nil);

  FIcon := AImage;
end;

{$REGION 'Create'}


constructor TSettingsForm.Create(Parent: HWND; AService: IAIMPServiceUI);
var
  LVersionInfo: IAIMPServiceVersionInfo;
begin
  FService := AService;

  FUIStyleLight := True;
  FSettingsList := TObjectDictionary<string, TSettingItemEx>.Create([doOwnsValues]);

  CheckResult(FService.CreateForm(Parent, AIMPUI_SERVICE_CREATEFORM_FLAGS_CHILD, MakeString('settings_form'), Self, FForm));
  PropListSetInt32(FForm, AIMPUI_FORM_PROPID_BORDERSTYLE, AIMPUI_FLAGS_BORDERSTYLE_NONE);
  PropListSetInt32(FForm, AIMPUI_FORM_PROPID_BORDERICONS, 1);
  PropListSetInt32(FForm, AIMPUI_FORM_PROPID_PADDING, 0);

  if Succeeded(FService.CreateObject(FForm, nil, IAIMPUIImageList, FImageList)) then
    CheckResult(FImageList.LoadFromResource(HInstance, 'button_images', 'PNG'));

  CreateProgsList(FForm);
  CreateEditor(FForm);
  CreateImport(FForm);

  if CoreGetService(IID_IAIMPServiceVersionInfo, LVersionInfo) and (LVersionInfo.GetBuildNumber >= 2130) then
    FUIStyleLight := PropListGetInt32(FForm, AIMPUI_FORM_PROPID_STYLE) = AIMPUI_STYLE_LIGHT;
end;

procedure TSettingsForm.CreateProgsList(AParent: IAIMPUIWinControl);
var
  LPanel: IAIMPUIPanel;
  LColumn: IAIMPUITreeListColumn;
  LMenuItem: IAIMPUIMenuItem;
begin
  // Programs Panel
  CheckResult(FService.CreateControl(FForm, AParent, MakeString('panel_programs'), Self, IID_IAIMPUIPanel, LPanel));
  CheckResult(LPanel.SetPlacement(TAIMPUIControlPlacement.Create(ualTop, 325)));
  PropListSetInt32(LPanel, AIMPUI_PANEL_PROPID_PADDING, 0);
  // Programs TreeList
  CheckResult(FService.CreateControl(FForm, LPanel, MakeString('treelist_programs'), Self, IAIMPUITreeList, FTreeListPrograms));
  CheckResult(FTreeListPrograms.SetPlacement(TAIMPUIControlPlacement.Create(ualTop, 285, NullRect)));
  PropListSetInt32(FTreeListPrograms, AIMPUI_TL_PROPID_COLUMN_VISIBLE, 0);
  PropListSetInt32(FTreeListPrograms, AIMPUI_TL_PROPID_BORDERS, AIMPUI_FLAGS_BORDER_BOTTOM);
  PropListSetInt32(FTreeListPrograms, AIMPUI_TL_PROPID_NODE_HEIGHT, 50);
  PropListSetInt32(FTreeListPrograms, AIMPUI_TL_PROPID_COLUMN_AUTOWIDTH, 1);
  PropListSetInt32(FTreeListPrograms, AIMPUI_TL_PROPID_DRAG_SORTING, 1);
  // Programs Column
  CheckResult(FTreeListPrograms.AddColumn(IAIMPUITreeListColumn, LColumn));
  PropListSetInt32(LColumn, AIMPUI_TL_COLUMN_PROPID_VISIBLE, 0);
  // Programs Add Button PopupMenu
  CheckResult(FService.CreateObject(FForm, nil, IAIMPUIPopupMenu, FDropDownMenuAdd));
  CheckResult(FDropDownMenuAdd.Add(MakeString('openwith.popup.addurl'), LMenuItem));
  PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_EVENT, TAIMPUINotifyEventAdapter.Create(OnPopupItemClick));
  PropListSetInt32(LMenuItem, AIMP_MENUITEM_PROPID_DEFAULT, 1);
  // Programs Add Button
  CheckResult(FService.CreateControl(FForm, LPanel, MakeString('button_add'), Self, IAIMPUIButton, FButtonAdd));
  CheckResult(FButtonAdd.SetPlacement(TAIMPUIControlPlacement.Create(ualNone, Bounds(302, 292, 100, 25))));
  PropListSetInt32(FButtonAdd, AIMPUI_BUTTON_PROPID_STYLE, AIMPUI_FLAGS_BUTTON_STYLE_DROPDOWNBUTTON);
  PropListSetObj(FButtonAdd, AIMPUI_BUTTON_PROPID_DROPDOWNMENU, FDropDownMenuAdd);
  // Programs Delete Button
  CheckResult(FService.CreateControl(FForm, LPanel, MakeString('button_delete'), Self, IAIMPUIButton, FButtonDelete));
  CheckResult(FButtonDelete.SetPlacement(TAIMPUIControlPlacement.Create(ualNone, Bounds(411, 292, 70, 25))));
end;

procedure TSettingsForm.CreateEditor(AParent: IAIMPUIWinControl);

  function CreateLabel(AParent: IAIMPUIWinControl; const AName: string; Bounds: TRect): IAIMPUILabel;
  begin
    CheckResult(FService.CreateControl(FForm, AParent, MakeString(AName), nil, IAIMPUILabel, Result));
    CheckResult(Result.SetPlacement(TAIMPUIControlPlacement.Create(ualNone, Bounds)));
    PropListSetInt32(Result, AIMPUI_LABEL_PROPID_AUTOSIZE, 1);
  end;

var
  LGroupBox: IAIMPUIWinControl;
  LButton: IAIMPUIEditButton;
  LMenuItem: IAIMPUIMenuItem;
begin
  // Editor GroupBox
  CheckResult(FService.CreateControl(FForm, AParent, MakeString('groupbox_editor'), Self, IID_IAIMPUIGroupBox, LGroupBox));
  CheckResult(LGroupBox.SetPlacement(TAIMPUIControlPlacement.Create(ualTop, 100)));
  // Path
  FLabelPath := CreateLabel(LGroupBox, 'label_path', Bounds(11, 9, 0, 0));
  CheckResult(FService.CreateControl(FForm, LGroupBox, MakeString('edit_path'), Self, IAIMPUIEdit, FEditPath));
  CheckResult(FEditPath.SetPlacement(TAIMPUIControlPlacement.Create(ualNone, Bounds(9, 25, 472, 0))));
  CheckResult(FEditPath.AddButton(TAIMPUINotifyEventAdapter.Create(OnPathButtonClick), LButton));
  PropListSetObj(LButton, AIMPUI_EDITBUTTON_PROPID_CAPTION, MakeString('...'));
  PropListSetInt32(LButton, AIMPUI_EDITBUTTON_PROPID_WIDTH, 50);
  // Title
  FLabelTitle := CreateLabel(LGroupBox, 'label_title', Bounds(11, 52, 0, 0));
  CheckResult(FService.CreateControl(FForm, LGroupBox, MakeString('edit_title'), Self, IAIMPUIEdit, FEditTitle));
  CheckResult(FEditTitle.SetPlacement(TAIMPUIControlPlacement.Create(ualNone, Bounds(9, 68, 192, 0))));
  // Params
  FLabelParams := CreateLabel(LGroupBox, 'label_params', Bounds(210, 52, 0, 0));
  CheckResult(FService.CreateControl(FForm, LGroupBox, MakeString('edit_params'), Self, IAIMPUIEdit, FEditParams));
  CheckResult(FEditParams.SetPlacement(TAIMPUIControlPlacement.Create(ualNone, Bounds(208, 68, 273, 0))));
  PropListSetObj(FEditParams, AIMPUI_BUTTONEDEDIT_PROPID_BUTTONSIMAGES, FImageList);
  CheckResult(FEditParams.AddButton(TAIMPUINotifyEventAdapter.Create(OnParamsButtonClick), LButton));
  PropListSetInt32(LButton, AIMPUI_EDITBUTTON_PROPID_IMAGEINDEX, 0);
  // Params PopupMenu
  CheckResult(FService.CreateObject(FForm, nil, IAIMPUIPopupMenu, FPopupMenuParams));
  // %Files%
  CheckResult(FPopupMenuParams.Add(MakeString('openwith.popup.files'), LMenuItem));
  PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_EVENT, TAIMPUINotifyEventAdapter.Create(OnPopupItemClick));
  PropListSetInt32(LMenuItem, AIMP_MENUITEM_PROPID_DEFAULT, 1);
  // %Folders%
  CheckResult(FPopupMenuParams.Add(MakeString('openwith.popup.folders'), LMenuItem));
  PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_EVENT, TAIMPUINotifyEventAdapter.Create(OnPopupItemClick));
  // %AIMP Pause%
  CheckResult(FPopupMenuParams.Add(MakeString('openwith.popup.pause'), LMenuItem));
  PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_EVENT, TAIMPUINotifyEventAdapter.Create(OnPopupItemClick));
  // %AIMP Stop%
  CheckResult(FPopupMenuParams.Add(MakeString('openwith.popup.stop'), LMenuItem));
  PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_EVENT, TAIMPUINotifyEventAdapter.Create(OnPopupItemClick));
end;

procedure TSettingsForm.CreateImport(AParent: IAIMPUIWinControl);

  procedure CreateLabel(AParent: IAIMPUIWinControl; const AName: string; Alignment: TRect);
  var LLabel: IAIMPUILabel;
  begin
    CheckResult(FService.CreateControl(FForm, AParent, MakeString(AName),
      TAIMPUIMouseEventsAdapter.Create(nil, OnLabelMouseClick, nil, nil, nil), IAIMPUILabel, LLabel));
    CheckResult(LLabel.SetPlacement(TAIMPUIControlPlacement.Create(ualRight, 0, Alignment)));
    PropListSetInt32(LLabel, AIMPUI_LABEL_PROPID_AUTOSIZE, 1);
    PropListSetObj(LLabel, AIMPUI_LABEL_PROPID_URL, MakeString('fakeurl'));
  end;

begin
  CreateLabel(AParent, 'label_export', Rect(10, 0, 5, 0));
  CreateLabel(AParent, 'label_import', NullRect);
end;

{$ENDREGION}


procedure TSettingsForm.ApplyLocalization;
var
  LMenu: TMenuManager;
begin
  FPathLangStr := LangLoadString('settings_form\label_path');
  FParamLangStr := LangLoadString('settings_form\label_params');

  LMenu := TMenuManager.Create;
  try
    LMenu.UpdateLocalization;
  finally
    FreeAndNil(LMenu);
  end;
end;

procedure TSettingsForm.ConfigLoad;
var
  LSortedKeys: TList<string>;
begin
  FModified := True;
  FSettingsList.Clear;
  FTreeListPrograms.Clear;
  FSelectedNodeID := '';

  LSortedKeys := TGlobals.Settings.GetSortedByOrderKeys;
  try
    for var LCount: Integer := 0 to LSortedKeys.Count - 1 do
    begin
      FSettingsList.Add(LSortedKeys[LCount],
        TSettingItemEx.Create(
        TGlobals.Settings[LSortedKeys[LCount]].Title,
        TGlobals.Settings[LSortedKeys[LCount]].Path,
        TGlobals.Settings[LSortedKeys[LCount]].Param,
        TGlobals.Settings[LSortedKeys[LCount]].ItemType,
        TImageContainer.ToImage(TGlobals.Settings[LSortedKeys[LCount]].Image, 32))
        );

      AddNodeToTreeList(LSortedKeys[LCount]);
    end;

    OnStructChanged(nil);
  finally
    FreeAndNil(LSortedKeys);
  end;
end;

procedure TSettingsForm.ConfigSave;
var
  LMenu: TMenuManager;
  LNode: IAIMPUITreeListNode;
  LRootNode: IAIMPUITreeListNode;
  LTempStr: IAIMPString;
  LItemID: string;
begin
  if Succeeded(FTreeListPrograms.GetRootNode(IID_IAIMPUITreeListNode, LRootNode)) then
  begin
    TGlobals.Settings.Clear;

    for var LCount: Integer := 0 to LRootNode.GetCount - 1 do
    begin
      CheckResult(LRootNode.Get(LCount, IID_IAIMPUITreeListNode, LNode));
      CheckResult(LNode.GetValue(0, LTempStr));
      LItemID := IAIMPStringToString(LTempStr);

      if FSettingsList.ContainsKey(LItemID) then
        TGlobals.Settings.Add(LItemID,
          TSettingItem.Create(
          FSettingsList[LItemID].Title,
          FSettingsList[LItemID].Path,
          FSettingsList[LItemID].Param,
          LCount,
          FSettingsList[LItemID].ItemType,
          TImageContainer.FromImage(FSettingsList[LItemID].Icon)
          ));
    end;

    TGlobals.Settings.Save;

    LMenu := TMenuManager.Create;
    try
      LMenu.UpdateMenu;
    finally
      FreeAndNil(LMenu);
    end;
  end;
end;

procedure TSettingsForm.DoModified;
begin
  if Assigned(OnModified) then
    OnModified(Self);
end;

procedure TSettingsForm.AddNodeToTreeList(const ID: string; Focused: Boolean);
var
  LRootNode, LNode: IAIMPUITreeListNode;
begin
  if Succeeded(FTreeListPrograms.GetRootNode(IID_IAIMPUITreeListNode, LRootNode)) and Succeeded(LRootNode.Add(LNode)) then
  begin
    CheckResult(LNode.SetValue(0, MakeString(ID)));

    if Focused and Succeeded(FTreeListPrograms.SetFocus) then
      CheckResult(FTreeListPrograms.SetFocused(LNode));
  end;
end;

procedure TSettingsForm.OnURLButtonClick(const Sender: IInterface);
var
  LItemID: string;
begin
  LItemID := TUtilities.CreateGUID;
  FSettingsList.Add(LItemID, TSettingItemEx.Create('sample.com', 'https://sample.com/?q=%s', '%Artist %Album', Url,
    TImageContainer.ToImage(TImageContainer.FromResource('icon_url'), 32)));

  AddNodeToTreeList(LItemID, True);
  DoModified;
end;

procedure TSettingsForm.OnPathButtonClick(const Sender: IInterface);
var
  LFileDialogs: IAIMPUIFileDialogs;
  LFileName: IAIMPString;
  LItemID: string;
begin
  CheckResult(FService.QueryInterface(IAIMPUIFileDialogs, LFileDialogs));
  if Succeeded(LFileDialogs.ExecuteOpenDialog(FForm.GetHandle, nil, MakeString('|*.exe'), LFileName)) then
  begin
    if Sender = FButtonAdd then
    begin
      LItemID := TUtilities.CreateGUID;
      FSettingsList.Add(LItemID, TSettingItemEx.Create('', '', '', App, nil));
      AddNodeToTreeList(LItemID, True);
    end
    else
    begin
      if not FSettingsList.ContainsKey(FSelectedNodeID) then
        Exit;

      LItemID := FSelectedNodeID;
      FSettingsList[LItemID].ItemType := App;
    end;

    PropListSetObj(FEditPath, AIMPUI_BASEEDIT_PROPID_TEXT, LFileName);
    PropListSetStr(FEditTitle, AIMPUI_BASEEDIT_PROPID_TEXT, GetAppTitle(IAIMPStringToString(LFileName)));

    // Если ProductName получить не удалось - заполняю именем файла
    if PropListGetStr(FEditTitle, AIMPUI_BASEEDIT_PROPID_TEXT).Length <= 0 then
      PropListSetStr(FEditTitle, AIMPUI_BASEEDIT_PROPID_TEXT, TPath.GetFileNameWithoutExtension(IAIMPStringToString(LFileName)));

    if PropListGetStr(FEditParams, AIMPUI_BASEEDIT_PROPID_TEXT).Length <= 0 then
      PropListSetStr(FEditParams, AIMPUI_BASEEDIT_PROPID_TEXT, '%Files%');

    FSettingsList[LItemID].Icon := TImageContainer.ToImage(TImageContainer.FromAppIcon(IAIMPStringToString(LFileName)), 32);

    DoModified;
  end;
end;

procedure TSettingsForm.OnPopupItemClick(const Sender: IInterface);
var
  LMenuID: string;
begin
  if PropListGetStr((Sender as IAIMPUIMenuItem), AIMP_MENUITEM_PROPID_ID, LMenuID) then
  begin
    if LMenuID = 'openwith.popup.addurl' then
      OnURLButtonClick(nil)
    else if LMenuID = 'openwith.popup.files' then
      PropListSetStr(FEditParams, AIMPUI_BASEEDIT_PROPID_SELTEXT, '%Files%')
    else if LMenuID = 'openwith.popup.folders' then
      PropListSetStr(FEditParams, AIMPUI_BASEEDIT_PROPID_SELTEXT, '%Folders%')
    else if LMenuID = 'openwith.popup.pause' then
      PropListSetStr(FEditParams, AIMPUI_BASEEDIT_PROPID_SELTEXT, '%AIMP Pause%')
    else if LMenuID = 'openwith.popup.stop' then
      PropListSetStr(FEditParams, AIMPUI_BASEEDIT_PROPID_SELTEXT, '%AIMP Stop%');
  end;
end;

procedure TSettingsForm.OnExecute(Data: IInterface);
begin
  PropListSetObj(FEditParams, AIMPUI_BASEEDIT_PROPID_SELTEXT, Data);
end;

procedure TSettingsForm.OnParamsButtonClick(const Sender: IInterface);
var
  LPoint: TPoint;
  LFileInfoFormatterUtils: IAIMPServiceFileInfoFormatterUtils;
begin
  if not FSettingsList.ContainsKey(FSelectedNodeID) then
    Exit;

  GetCursorPos(LPoint);
  case FSettingsList[FSelectedNodeID].ItemType of
    App:
      CheckResult(FPopupMenuParams.Popup(LPoint));
    Url:
      begin
        if CoreGetService(IID_IAIMPServiceFileInfoFormatterUtils, LFileInfoFormatterUtils) then
          CheckResult(LFileInfoFormatterUtils.ShowMacrosLegend(Rect(LPoint.X, LPoint.Y, LPoint.X, LPoint.Y), 0, Self));
      end;
  end;
end;

procedure TSettingsForm.OnChanged(Sender: IInterface);
type
  TControlSet = (edit_title, edit_path, edit_params, button_add, button_delete);
var
  LUIControl: IAIMPUIControl;
  LNode: IAIMPUITreeListNode;
  LCurrentControl: TControlSet;
begin
  if not FModified then
    Exit;

  if Supports(Sender, IAIMPUIControl, LUIControl) then
  begin
    LCurrentControl := TControlSet(GetEnumValue(TypeInfo(TControlSet), PropListGetStr(LUIControl, AIMPUI_CONTROL_PROPID_NAME)));
    if not FSettingsList.ContainsKey(FSelectedNodeID) and (LCurrentControl <> button_add) then
      Exit;

    case LCurrentControl of
      edit_title:
        begin
          FSettingsList[FSelectedNodeID].Title := PropListGetStr(FEditTitle, AIMPUI_BASEEDIT_PROPID_TEXT);
          FTreeListPrograms.Invalidate;
        end;
      edit_path:
        begin
          FSettingsList[FSelectedNodeID].Path := PropListGetStr(FEditPath, AIMPUI_BASEEDIT_PROPID_TEXT);
          FTreeListPrograms.Invalidate;
        end;
      edit_params:
        begin
          FSettingsList[FSelectedNodeID].Param := PropListGetStr(FEditParams, AIMPUI_BASEEDIT_PROPID_TEXT);
          FTreeListPrograms.Invalidate;
        end;
      button_add:
        OnPathButtonClick(FButtonAdd);
      button_delete:
        begin
          if Succeeded(FTreeListPrograms.GetFocused(IID_IAIMPUITreeListNode, LNode)) then
          begin
            FSettingsList.Remove(FSelectedNodeID);
            CheckResult(FTreeListPrograms.Delete(LNode));
          end;
        end;
    end;
    DoModified;
  end;
end;

procedure TSettingsForm.OnLabelMouseClick(const Sender: IInterface; Button: TAIMPUIMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LFileName: IAIMPString;
  LFileDialogs: IAIMPUIFileDialogs;
  LTmpSettings: TSettings;
  LNeonConfig: INeonConfiguration;
  LItemID: string;
begin
  CheckResult(FService.QueryInterface(IAIMPUIFileDialogs, LFileDialogs));

  if PropListGetStr((Sender as IAIMPUIControl), AIMPUI_CONTROL_PROPID_NAME) = 'label_import' then
  begin
    if Succeeded(LFileDialogs.ExecuteOpenDialog(FForm.GetHandle, nil, MakeString('|*.json'), LFileName)) then
    begin
      if not TFile.Exists(IAIMPStringToString(LFileName)) then
        Exit;

      LTmpSettings := TSettings.Create;
      try
        LNeonConfig := TNeonConfiguration.Default.SetMembers([TNeonMembers.Standard, TNeonMembers.Fields]);
        LNeonConfig.GetSerializers.RegisterSerializer(TImageContainerSerializer);
        TNeon.JSONToObject(LTmpSettings, TFile.ReadAllText(IAIMPStringToString(LFileName), TEncoding.UTF8), LNeonConfig);

        if LTmpSettings.Count <= 0 then
          Exit;

        var LSortedKeys: TList<string> := LTmpSettings.GetSortedByOrderKeys;
        try
          for var LCount: Integer := 0 to LSortedKeys.Count - 1 do
          begin
            if (LTmpSettings[LSortedKeys[LCount]].Title.Length = 0) or (LTmpSettings[LSortedKeys[LCount]].Path.Length = 0) then
              Continue;

            LItemID := TUtilities.CreateGUID;

            FSettingsList.Add(LItemID,
              TSettingItemEx.Create(
              LTmpSettings[LSortedKeys[LCount]].Title,
              LTmpSettings[LSortedKeys[LCount]].Path,
              LTmpSettings[LSortedKeys[LCount]].Param,
              LTmpSettings[LSortedKeys[LCount]].ItemType,
              TImageContainer.ToImage(LTmpSettings[LSortedKeys[LCount]].Image, 32))
              );

            AddNodeToTreeList(LItemID);
          end;
        finally
          FreeAndNil(LSortedKeys);
        end;

        OnStructChanged(nil);
        DoModified;
      finally
        FreeAndNil(LTmpSettings);
      end;
    end;
  end
  else
  begin
    var LFilterIndex: Integer;

    if Succeeded(LFileDialogs.ExecuteSaveDialog(FForm.GetHandle, nil, MakeString('|*.json;'), LFileName, LFilterIndex)) then
    begin
      var LNode: IAIMPUITreeListNode;
      var LRootNode: IAIMPUITreeListNode;
      var LTempStr: IAIMPString;

      LTmpSettings := TSettings.Create;
      try
        if Succeeded(FTreeListPrograms.GetRootNode(IID_IAIMPUITreeListNode, LRootNode)) then
        begin
          for var LCount: Integer := 0 to LRootNode.GetCount - 1 do
          begin
            CheckResult(LRootNode.Get(LCount, IID_IAIMPUITreeListNode, LNode));
            CheckResult(LNode.GetValue(0, LTempStr));
            LItemID := IAIMPStringToString(LTempStr);

            if FSettingsList.ContainsKey(LItemID) then
              LTmpSettings.Add(LItemID,
                TSettingItem.Create(
                FSettingsList[LItemID].Title,
                FSettingsList[LItemID].Path,
                FSettingsList[LItemID].Param,
                LCount,
                FSettingsList[LItemID].ItemType,
                TImageContainer.FromImage(FSettingsList[LItemID].Icon)
                ));
          end;
        end;

        LNeonConfig := TNeonConfiguration.Default.SetMembers([TNeonMembers.Standard, TNeonMembers.Fields]);
        LNeonConfig.GetSerializers.RegisterSerializer(TImageContainerSerializer);
        TFile.WriteAllText(IAIMPStringToString(LFileName), TNeon.ObjectToJSONString(LTmpSettings, LNeonConfig), TEncoding.UTF8);
      finally
        FreeAndNil(LTmpSettings);
      end;
    end;
  end;
end;

procedure TSettingsForm.OnFocusedNodeChanged(Sender: IAIMPUITreeList);
var
  LNode: IAIMPUITreeListNode;
  LTempStr: IAIMPString;
begin
  FModified := False;
  try
    // TreeList > Editor
    if Succeeded(FTreeListPrograms.GetFocused(IID_IAIMPUITreeListNode, LNode)) then
    begin
      CheckResult(LNode.GetValue(0, LTempStr));
      FSelectedNodeID := IAIMPStringToString(LTempStr);
      if not FSettingsList.ContainsKey(FSelectedNodeID) then
        Exit;

      PropListSetStr(FEditTitle, AIMPUI_BASEEDIT_PROPID_TEXT, FSettingsList[FSelectedNodeID].Title);
      PropListSetStr(FEditPath, AIMPUI_BASEEDIT_PROPID_TEXT, FSettingsList[FSelectedNodeID].Path);
      PropListSetStr(FEditParams, AIMPUI_BASEEDIT_PROPID_TEXT, FSettingsList[FSelectedNodeID].Param);
      PropListSetStr(FLabelPath, AIMPUI_LABEL_PROPID_TEXT,
        IfThen(FSettingsList[FSelectedNodeID].ItemType = Url, 'URL', FPathLangStr));
    end;
  finally
    FModified := True;
  end;
end;

procedure TSettingsForm.OnStructChanged(Sender: IAIMPUITreeList);
var
  LRootNode: IAIMPUITreeListNode;
  LEnabled: Integer;
begin
  if not Assigned(FEditParams) then
    Exit;

  if Succeeded(FTreeListPrograms.GetRootNode(IID_IAIMPUITreeListNode, LRootNode)) then
  begin
    if LRootNode.GetCount <= 0 then
    begin
      LEnabled := 0;
      FSettingsList.Clear;
      PropListSetObj(FEditTitle, AIMPUI_BASEEDIT_PROPID_TEXT, nil);
      PropListSetObj(FEditPath, AIMPUI_BASEEDIT_PROPID_TEXT, nil);
      PropListSetObj(FEditParams, AIMPUI_BASEEDIT_PROPID_TEXT, nil);
    end
    else
      LEnabled := 1;

    PropListSetInt32(FButtonDelete, AIMPUI_CONTROL_PROPID_ENABLED, LEnabled);
    PropListSetInt32(FLabelPath, AIMPUI_CONTROL_PROPID_ENABLED, LEnabled);
    PropListSetInt32(FLabelTitle, AIMPUI_CONTROL_PROPID_ENABLED, LEnabled);
    PropListSetInt32(FLabelParams, AIMPUI_CONTROL_PROPID_ENABLED, LEnabled);
    PropListSetInt32(FEditPath, AIMPUI_CONTROL_PROPID_ENABLED, LEnabled);
    PropListSetInt32(FEditTitle, AIMPUI_CONTROL_PROPID_ENABLED, LEnabled);
    PropListSetInt32(FEditParams, AIMPUI_CONTROL_PROPID_ENABLED, LEnabled);
  end;
end;

procedure TSettingsForm.OnStyleChanged(Sender: IAIMPUIForm; Style: Integer);
begin
  FUIStyleLight := Style = AIMPUI_STYLE_LIGHT;
end;

procedure TSettingsForm.OnCustomDrawNode(Sender: IAIMPUITreeList; DC: HDC; R: TRect; Node: IAIMPUITreeListNode; var Handled: LongBool);
const
  clItemSelectedLight = TColor($9FD5FF);
  clItemSelectedDark = TColor($23507C);
  clItemInvalidLight = TColor($D4D2FF);
  clItemInvalidDark = TColor($0E5AFF);
  clItemOneLight = TColor($FBFBFB);
  clItemOneDark = TColor($303030);
  clItemTwoDark = TColor($2A2A2A);
var
  LCanvas: TCanvas;
  LDpi: Integer;
  LDpiAware: IAIMPDPIAware;
  LItem: TSettingItemEx;
  LItemID: string;
  LRect: TRect;
  LTempStr: IAIMPString;
begin
  LCanvas := TCanvas.Create;
  try
    LCanvas.Handle := DC;
    Handled := True;

    if Supports(Sender, IAIMPDPIAware, LDpiAware) then
      LDpi := LDpiAware.GetDPI
    else
      LDpi := 96;

    Node.GetValue(0, LTempStr);
    LItemID := IAIMPStringToString(LTempStr);
    if FSettingsList.ContainsKey(LItemID) then
      LItem := FSettingsList[LItemID]
    else
      Exit;

    // Item Color
    // Выделенный
    if PropListGetInt32(Node, AIMPUI_TL_NODE_PROPID_SELECTED) <> 0 then
      LCanvas.Brush.Color := IfThen(FUIStyleLight, clItemSelectedLight, clItemSelectedDark)
      // Нерабочий
    else if not TUtilities.ValidItem(LItem) then
      LCanvas.Brush.Color := IfThen(FUIStyleLight, clItemInvalidLight, clItemInvalidDark)
      // "Лесенкой" 2 разных цвета
    else if Odd(PropListGetInt32(Node, AIMPUI_TL_NODE_PROPID_ABS_VISIBLE_INDEX)) then
      LCanvas.Brush.Color := IfThen(FUIStyleLight, clItemOneLight, clItemOneDark)
    else
      LCanvas.Brush.Color := IfThen(FUIStyleLight, clWhite, clItemTwoDark);

    LCanvas.FillRect(R);

    // Icon
    if Assigned(LItem.Icon) then
      LItem.Icon.Draw(LCanvas.Handle,
        Bounds(dpiValue(10, LDpi), dpiValue(10, LDpi), dpiValue(32, LDpi), dpiValue(32, LDpi)),
        AIMP_IMAGE_DRAW_QUALITY_HIGH, nil);

    // Text
    LCanvas.Font.Color := IfThen(FUIStyleLight, clBlack);
    LCanvas.Font.Quality := fqClearType;
    // Title
    LCanvas.Font.Style := LCanvas.Font.Style + [fsBold];
    LCanvas.TextOut(R.Left + dpiValue(52, LDpi), R.Top + dpiValue(4, LDpi), LItem.Title);
    LCanvas.Font.Style := LCanvas.Font.Style - [fsBold];
    // Path
    LCanvas.TextOut(R.Left + dpiValue(52, LDpi), R.Top + dpiValue(18, LDpi), IfThen(LItem.ItemType = Url, 'URL: ', FPathLangStr + ': '));
    LRect := Bounds(dpiValue(62, LDpi) + LCanvas.TextWidth(FPathLangStr), dpiValue(18, LDpi), R.Width - (dpiValue(70, LDpi) + LCanvas.TextWidth(FPathLangStr)), 20);
    DrawText(LCanvas.Handle, LItem.Path, LItem.Path.Length, LRect, DT_PATH_ELLIPSIS or DT_NOPREFIX);
    // Params
    LCanvas.TextOut(R.Left + dpiValue(52, LDpi), R.Top + dpiValue(32, LDpi), FParamLangStr + ': ');
    LRect := Bounds(dpiValue(62, LDpi) + LCanvas.TextWidth(FPathLangStr), dpiValue(32, LDpi), R.Width - (dpiValue(70, LDpi) + LCanvas.TextWidth(FPathLangStr)), 20);
    DrawText(LCanvas.Handle, LItem.Param, LItem.Param.Length, LRect, DT_WORD_ELLIPSIS or DT_NOPREFIX);

    if PropListGetInt32(Node, AIMPUI_WINCONTROL_PROPID_FOCUSED) = 1 then
      LCanvas.DrawFocusRect(R);
  finally
    FreeAndNil(LCanvas);
    LTempStr := nil;
  end;
end;

procedure TSettingsForm.OnSorted(Sender: IAIMPUITreeList);
begin
  DoModified;
end;

procedure TSettingsForm.OnDestroyed(Sender: IAIMPUIForm);
begin
  FEditPath := nil;
  FEditTitle := nil;
  FEditParams := nil;
  FPopupMenuParams := nil;
  FDropDownMenuAdd := nil;
  FImageList := nil;
  FTreeListPrograms := nil;
  FButtonAdd := nil;
  FButtonDelete := nil;
  FLabelPath := nil;
  FLabelTitle := nil;
  FLabelParams := nil;

  FreeAndNil(FSettingsList);
  FForm := nil;
end;

// Получение ProductName из exe файла
function TSettingsForm.GetAppTitle(const FileName: string): string;
type
  PLandCodepage = ^TLandCodepage;

  TLandCodepage = record
    wLanguage, wCodePage: Word;
  end;

var
  LDummy, LLength: cardinal;
  LBuffer, pntr: pointer;
  LLanguage: string;
begin
  LLength := GetFileVersionInfoSize(PChar(FileName), LDummy);
  if LLength = 0 then
    Exit;
  GetMem(LBuffer, LLength);
  try
    if not GetFileVersionInfo(PChar(FileName), 0, LLength, LBuffer) then
      Exit;
    if not VerQueryValue(LBuffer, '\VarFileInfo\Translation\', pntr, LLength) then
      Exit;

    LLanguage := Format('%.4x%.4x', [PLandCodepage(pntr)^.wLanguage, PLandCodepage(pntr)^.wCodePage]);
    if VerQueryValue(LBuffer, PChar('\StringFileInfo\' + LLanguage + '\ProductName'), pntr, LLength) then
      Result := PChar(pntr);
  finally
    FreeMem(LBuffer);
  end;
end;

{$REGION 'do nothing'}


procedure TSettingsForm.OnSelectionChanged(Sender: IAIMPUITreeList);
begin
  // do nothing
end;

procedure TSettingsForm.OnShortCut(Sender: IAIMPUIForm; Key, Modifiers: Word; var Handled: LongBool);
begin
  // do nothing
end;

procedure TSettingsForm.OnActivated(Sender: IAIMPUIForm);
begin
  // do nothing
end;

procedure TSettingsForm.OnCloseQuery(Sender: IAIMPUIForm; var CanClose: LongBool);
begin
  // do nothing
end;

procedure TSettingsForm.OnColumnClick(Sender: IAIMPUITreeList; ColumnIndex: Integer);
begin
  // do nothing
end;

procedure TSettingsForm.OnCreated(Sender: IAIMPUIForm);
begin
  // do nothing
end;

procedure TSettingsForm.OnDeactivated(Sender: IAIMPUIForm);
begin
  // do nothing
end;

procedure TSettingsForm.OnLocalize(Sender: IAIMPUIForm);
begin
  // do nothing
end;

procedure TSettingsForm.OnNodeChecked(Sender: IAIMPUITreeList; Node: IAIMPUITreeListNode);
begin
  // do nothing
end;

procedure TSettingsForm.OnNodeDblClicked(Sender: IAIMPUITreeList; Node: IAIMPUITreeListNode);
begin
  // do nothing
end;

procedure TSettingsForm.OnFocusedColumnChanged(Sender: IAIMPUITreeList);
begin
  // do nothing
end;

procedure TSettingsForm.OnCustomDrawNodeCell(Sender: IAIMPUITreeList; DC: HDC; R: TRect; Node: IAIMPUITreeListNode;
  Column: IAIMPUITreeListColumn; var Handled: LongBool);
begin
  // do nothing
end;

procedure TSettingsForm.OnGetNodeBackground(Sender: IAIMPUITreeList; Node: IAIMPUITreeListNode; var Color: DWORD);
begin
  // do nothing
end;
{$ENDREGION}

end.
