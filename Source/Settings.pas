unit Settings;

interface

uses
  System.Generics.Collections,
  apiObjects,
  Neon.Core.Attributes;

type
  TItemType = (App, URL);

  TSettingItem = class
  strict private
    fTitle: string;
    fPath: string;
    fParam: string;
    fSortOrder: SmallInt;
    fType: TItemType;
    fImage: IAIMPImageContainer;
  public
    constructor Create(const ATitle, APath, AParam: string; ASortOrder: Shortint; AType: TItemType;
      AImage: IAIMPImageContainer);
  public
    property Title: string read fTitle write fTitle;
    property Path: string read fPath write fPath;
    property Param: string read fParam write fParam;
    property SortOrder: SmallInt read fSortOrder write fSortOrder;
    [NeonProperty('Type')]
    property ItemType: TItemType read fType write fType;
    property Image: IAIMPImageContainer read fImage write fImage;
  end;

  TSettings = class(TObjectDictionary<string, TSettingItem>)
  strict private
    procedure ConvertOldSettings;
  public
    constructor Create;
    procedure Load;
    procedure Save;
    function GetSortedByOrderKeys: TList<string>;
  end;

implementation

uses
  Utilities,
  System.SysUtils,
  System.IOUtils,
  System.Generics.Defaults,
  apiWrappers,
  Neon.Core.Types,
  Neon.Core.Persistence,
  Neon.Core.Persistence.JSON;

constructor TSettingItem.Create(const ATitle, APath, AParam: string; ASortOrder: Shortint; AType: TItemType;
  AImage: IAIMPImageContainer);
begin
  fTitle := ATitle;
  fPath := APath;
  fParam := AParam;
  fSortOrder := ASortOrder;
  fType := AType;
  fImage := AImage;
end;

constructor TSettings.Create;
begin
  inherited Create([doOwnsValues]);
end;

procedure TSettings.ConvertOldSettings;
const
  ItemType: array [Boolean] of TItemType = (App, URL);
var
  LConfig: TAIMPServiceConfig;
  LCount, LProgramCount: Integer;
  LType: TItemType;
  LImageContainer: IAIMPImageContainer;
begin
  LConfig := TAIMPServiceConfig.Create;
  try
    LProgramCount := LConfig.ReadInteger('aimp_openwith\ProgramCount');
    if LProgramCount = 0 then
      Exit;

    for LCount := 0 to LProgramCount do
    begin
      LType := ItemType[LConfig.ReadBool('aimp_openwith\type' + LCount.ToString, False)];

      case LType of
        App: LImageContainer := TImageContainer.FromAppIcon(LConfig.ReadString('aimp_openwith\path' + LCount.ToString));
        URL: LImageContainer := TImageContainer.FromResource('icon_url');
      end;

      Self.Add(TUtilities.CreateGUID,
        TSettingItem.Create(
        LConfig.ReadString('aimp_openwith\title' + LCount.ToString),
        LConfig.ReadString('aimp_openwith\path' + LCount.ToString),
        LConfig.ReadString('aimp_openwith\param' + LCount.ToString).Replace('%Dirs%', '%Folders%'),
        LConfig.ReadInteger('aimp_openwith\index' + LCount.ToString, LCount),
        LType,
        LImageContainer));
    end;

    Save;
    LConfig.Service.Delete(MakeString('aimp_openwith'));
  finally
    FreeAndNil(LConfig);
  end;
end;

procedure TSettings.Load;
var
  LConfigFileName: string;
  LNeonConfig: INeonConfiguration;
begin
  LConfigFileName := TPath.Combine(CoreGetProfilePath, 'openwith_config.json');

  if TFile.Exists(LConfigFileName) then
  begin
    LNeonConfig := TNeonConfiguration.Default.SetMembers([TNeonMembers.Standard, TNeonMembers.Fields]);
    LNeonConfig.GetSerializers.RegisterSerializer(TImageContainerSerializer);

    TNeon.JSONToObject(Self, TFile.ReadAllText(LConfigFileName, TEncoding.UTF8), LNeonConfig);
  end
  else
    ConvertOldSettings;
end;

procedure TSettings.Save;
var
  LNeonConfig: INeonConfiguration;
begin
  LNeonConfig := TNeonConfiguration.Default.SetMembers([TNeonMembers.Standard, TNeonMembers.Fields]);
  LNeonConfig.GetSerializers.RegisterSerializer(TImageContainerSerializer);

  TFile.WriteAllText(
    TPath.Combine(CoreGetProfilePath, 'openwith_config.json'),
    TNeon.ObjectToJSONString(Self, LNeonConfig),
    TEncoding.UTF8);
end;

function TSettings.GetSortedByOrderKeys: TList<string>;
var
  LComparer: IComparer<string>;
begin
  LComparer := TDelegatedComparer<string>.Create(
    function(const Left, Right: string): Integer
    begin
      if Self[Left].SortOrder = Self[Right].SortOrder then
        Result := 0
      else if Self[Left].SortOrder > Self[Right].SortOrder then
        Result := 1
      else
        Result := -1;
    end);

  Result := TList<string>.Create(LComparer);
  Result.AddRange(Self.Keys);
  Result.Sort;
end;

end.
