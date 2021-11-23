unit Menu.Manager;

interface

uses
  System.Generics.Collections,
  apiMenu,
  apiActions,
  apiObjects;

type
  TMenuManager = class(TObject)
  private
    procedure UnregisterActions;
    procedure CreateSubMenu(AParent: IAIMPMenuItem; const APrefix, AActionGroup: string; AEvent: IAIMPActionEvent);
    function CreateMenuItem(AParent: IAIMPMenuItem; const AId: string; ATitle: IAIMPString; AGlyph: IAIMPImage): IAIMPMenuItem;
    function CreateAction(const AId, ATitle, AGroup, ACustom: string; AEvent: IAIMPActionEvent): IAIMPAction;
    function GetBuiltInMenu(AId: Integer): IAIMPMenuItem;
  public
    procedure CreateMenu;
    procedure UpdateMenu;
    procedure UpdateLocalization;
  end;

implementation

uses
  Plugin,
  Utilities,
  Menu.Action,
  Menu.Action.Playlist,
  Menu.Action.MediaLibrary,
  WinApi.Windows,
  System.SysUtils,
  apiCore,
  apiOptions,
  apiWrappers,
  apiPlaylists,
  apiMusicLibrary;

procedure TMenuManager.CreateMenu;
var
  LMenuItem: IAIMPMenuItem;
  LGlyph: IAIMPImage;
  LMenuTitle: IAIMPString;
  LMusicLibrary: IAIMPServiceMusicLibraryUI;
begin
  LMenuTitle := LangLoadStringEx('menu\openwith');
  LGlyph := TImageContainer.ToImage(TImageContainer.FromResource('menu_main'), 16);

  // Создание меню в плейлисте
  LMenuItem := CreateMenuItem(GetBuiltInMenu(AIMP_MENUID_PLAYER_PLAYLIST_CONTEXT_FUNCTIONS), 'openwith.pl.menu',
    LMenuTitle, LGlyph);
  PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_EVENT_ONSHOW, TPlaylistMenuShowEventHandler.Create);
  CreateSubMenu(LMenuItem, 'pl', LangLoadString('action\playlist'), TPlaylistActionEventHandler.Create);

  // Создание меню в фонотеке
  if not CoreGetService(IID_IAIMPServiceMusicLibraryUI, LMusicLibrary) then
    Exit;

  LMenuItem := CreateMenuItem(GetBuiltInMenu(AIMP_MENUID_ML_TABLE_CONTEXT_FUNCTIONS), 'openwith.ml.menu', LMenuTitle, LGlyph);
  PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_EVENT_ONSHOW, TLibraryMenuShowEventHandler.Create);
  CreateSubMenu(LMenuItem, 'ml', LangLoadString('action\audio_library'), TLibraryActionEventHandler.Create);
end;

procedure TMenuManager.CreateSubMenu(AParent: IAIMPMenuItem; const APrefix, AActionGroup: string; AEvent: IAIMPActionEvent);
const
  cActionTemplate: string = 'openwith.%s.action.%s';
  cSubMenuTemplate: string = 'openwith.%s.subitem.%s';
var
  LAction: IAIMPAction;
  LMenuItem: IAIMPMenuItem;
  LSortedKeys: TList<string>;
begin
  // Список программ
  LSortedKeys := TGlobals.Settings.GetSortedByOrderKeys;
  try
    for var LCount: Integer := 0 to LSortedKeys.Count - 1 do
    begin
      if TUtilities.ValidItem(TGlobals.Settings[LSortedKeys[LCount]]) then
      begin
        LAction := CreateAction(Format(cActionTemplate, [APrefix, LSortedKeys[LCount]]),
          TGlobals.Settings[LSortedKeys[LCount]].Title, 'OpenWith: ' + AActionGroup, LSortedKeys[LCount], AEvent);

        LMenuItem := CreateMenuItem(AParent, Format(cSubMenuTemplate, [APrefix, LSortedKeys[LCount]]), nil,
          TImageContainer.ToImage(TGlobals.Settings[LSortedKeys[LCount]].Image, 16));
        PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_ACTION, LAction);
      end;
    end;
  finally
    FreeAndNil(LSortedKeys);
  end;
  // Разделитель
  CreateMenuItem(AParent, Format(cSubMenuTemplate, [APrefix, 'split']), MakeString('-'), nil);
  // Настройки
  LMenuItem := CreateMenuItem(AParent, Format(cSubMenuTemplate, [APrefix, 'settings']),
    LangLoadStringEx('menu\settings'), TImageContainer.ToImage(TImageContainer.FromResource('menu_settings'), 16));

  if Assigned(LMenuItem) then
  begin
    PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_EVENT, TSettingsMenuEventHandler.Create);
    PropListSetInt32(LMenuItem, AIMP_MENUITEM_PROPID_DEFAULT, 1);
  end;
end;

procedure TMenuManager.UpdateMenu;
var
  LMenuService: IAIMPServiceMenuManager;
  LMusicLibrary: IAIMPServiceMusicLibraryUI;
  LMenuItem: IAIMPMenuItem;
begin
  UnregisterActions;

  if CoreGetService(IAIMPServiceMenuManager, LMenuService) then
  begin
    if Succeeded(LMenuService.GetByID(MakeString('openwith.pl.menu'), LMenuItem)) then
    begin
      CheckResult(LMenuItem.DeleteChildren);
      CreateSubMenu(LMenuItem, 'pl', LangLoadString('action\playlist'), TPlaylistActionEventHandler.Create);
    end;

    if CoreGetService(IID_IAIMPServiceMusicLibraryUI, LMusicLibrary) and
      Succeeded(LMenuService.GetByID(MakeString('openwith.ml.menu'), LMenuItem)) then
    begin
      CheckResult(LMenuItem.DeleteChildren);
      CreateSubMenu(LMenuItem, 'ml', LangLoadString('action\audio_library'), TLibraryActionEventHandler.Create);
    end;
  end;
end;

procedure TMenuManager.UpdateLocalization;
var
  LMenuManager: IAIMPServiceMenuManager;
  LMenuItem: IAIMPMenuItem;
  LMenuTitle, LSettingsTitle, LPlaylistGroupTitle, LLibraryGroupTitle: IAIMPString;
  LMusicLibrary: IAIMPServiceMusicLibraryUI;
  LHasLibrary: Boolean;
  LAction: IAIMPAction;
  LActionManager: IAIMPServiceActionManager;
begin
  LMenuTitle := LangLoadStringEx('menu\openwith');
  LSettingsTitle := LangLoadStringEx('menu\settings');
  LPlaylistGroupTitle := MakeString('OpenWith: ' + LangLoadString('action\playlist'));
  LLibraryGroupTitle := MakeString('OpenWith: ' + LangLoadString('action\audio_library'));
  LHasLibrary := CoreGetService(IID_IAIMPServiceMusicLibraryUI, LMusicLibrary);

  if CoreGetService(IAIMPServiceMenuManager, LMenuManager) then
  begin
    if Succeeded(LMenuManager.GetByID(MakeString('openwith.pl.menu'), LMenuItem)) then
      PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_NAME, LMenuTitle);
    if Succeeded(LMenuManager.GetByID(MakeString('openwith.pl.subitem.settings'), LMenuItem)) then
      PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_NAME, LSettingsTitle);

    if LHasLibrary and Succeeded(LMenuManager.GetByID(MakeString('openwith.ml.menu'), LMenuItem)) then
      PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_NAME, LMenuTitle);
    if LHasLibrary and Succeeded(LMenuManager.GetByID(MakeString('openwith.ml.subitem.settings'), LMenuItem)) then
      PropListSetObj(LMenuItem, AIMP_MENUITEM_PROPID_NAME, LSettingsTitle);
  end;

  if CoreGetService(IID_IAIMPServiceActionManager, LActionManager) then
  begin
    for var LKey: string in TGlobals.Settings.Keys do
    begin
      if Succeeded(LActionManager.GetByID(MakeString('openwith.pl.action.' + LKey), LAction)) then
        PropListSetObj(LAction, AIMP_ACTION_PROPID_GROUPNAME, LPlaylistGroupTitle);

      if LHasLibrary and Succeeded(LActionManager.GetByID(MakeString('openwith.ml.action.' + LKey), LAction)) then
        PropListSetObj(LAction, AIMP_ACTION_PROPID_GROUPNAME, LLibraryGroupTitle);
    end;
  end;
end;

function TMenuManager.CreateMenuItem(AParent: IAIMPMenuItem; const AId: string; ATitle: IAIMPString; AGlyph: IAIMPImage)
  : IAIMPMenuItem;
begin
  CheckResult(CoreIntf.CreateObject(IID_IAIMPMenuItem, Result));

  PropListSetStr(Result, AIMP_MENUITEM_PROPID_ID, AId);
  PropListSetObj(Result, AIMP_MENUITEM_PROPID_NAME, ATitle);
  PropListSetObj(Result, AIMP_MENUITEM_PROPID_PARENT, AParent);
  PropListSetObj(Result, AIMP_MENUITEM_PROPID_GLYPH, AGlyph);
  PropListSetInt32(Result, AIMP_MENUITEM_PROPID_STYLE, AIMP_MENUITEM_STYLE_NORMAL);

  CheckResult(CoreIntf.RegisterExtension(IID_IAIMPServiceMenuManager, Result));
end;

function TMenuManager.CreateAction(const AId, ATitle, AGroup, ACustom: string; AEvent: IAIMPActionEvent): IAIMPAction;
begin
  CheckResult(CoreIntf.CreateObject(IID_IAIMPAction, Result));

  PropListSetStr(Result, AIMP_ACTION_PROPID_ID, AId);
  PropListSetStr(Result, AIMP_ACTION_PROPID_NAME, ATitle);
  PropListSetStr(Result, AIMP_ACTION_PROPID_GROUPNAME, AGroup);
  PropListSetStr(Result, AIMP_ACTION_PROPID_CUSTOM, ACustom);
  PropListSetObj(Result, AIMP_ACTION_PROPID_EVENT, AEvent);

  CheckResult(CoreIntf.RegisterExtension(IID_IAIMPServiceActionManager, Result));
end;

procedure TMenuManager.UnregisterActions;
var
  LAction: IAIMPAction;
  LActionManager: IAIMPServiceActionManager;
begin
  if CoreGetService(IID_IAIMPServiceActionManager, LActionManager) then
  begin
    for var LKey: string in TGlobals.Settings.Keys do
    begin
      if Succeeded(LActionManager.GetByID(MakeString('openwith.pl.action.' + LKey), LAction)) then
        CheckResult(CoreIntf.UnregisterExtension(LAction));

      if Succeeded(LActionManager.GetByID(MakeString('openwith.ml.action.' + LKey), LAction)) then
        CheckResult(CoreIntf.UnregisterExtension(LAction));
    end;
  end;
end;

function TMenuManager.GetBuiltInMenu(AId: Integer): IAIMPMenuItem;
var
  LMenuManager: IAIMPServiceMenuManager;
begin
  if CoreGetService(IAIMPServiceMenuManager, LMenuManager) then
    CheckResult(LMenuManager.GetBuiltIn(AId, Result));
end;

end.
