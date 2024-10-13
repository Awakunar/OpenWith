unit Utilities;

interface

uses
  Settings,
  System.JSON,
  System.Rtti,
  System.TypInfo,
  System.Classes,
  Vcl.Graphics,
  apiObjects,
  Neon.Core.Persistence;

type
  TUtilities = class
  public
    class procedure ShellExec(const AOperation, AFileName: string; const AParameters: string = '');
    class function CreateGUID: string;
    class function ValidURL(const URL: Widestring): Boolean;
    class function ValidItem(const AItem: TSettingItem): Boolean;
  end;

  TImageContainer = class
  public
    class procedure FromStream(AContainer: IAIMPImageContainer; const AStream: TStream); inline;
    class function FromResource(const AResName: string; AContainer: IAIMPImageContainer = nil): IAIMPImageContainer;
    class function FromAppIcon(const AFileName: string; AContainer: IAIMPImageContainer = nil): IAIMPImageContainer;
    class function FromImage(const AImage: IAIMPImage; AContainer: IAIMPImageContainer = nil): IAIMPImageContainer;
    class function ToStream(const AContainer: IAIMPImageContainer): TMemoryStream;
    class function ToImage(const AContainer: IAIMPImageContainer; ASize: byte): IAIMPImage;
  end;

  TImageContainerSerializer = class(TCustomSerializer)
  protected
    class function GetTargetInfo: PTypeInfo; override;
    class function CanHandle(AType: PTypeInfo): Boolean; override;
  public
    function Serialize(const AValue: TValue; ANeonObject: TNeonRttiObject; AContext: ISerializerContext): TJSONValue; override;
    function Deserialize(AValue: TJSONValue; const AData: TValue; ANeonObject: TNeonRttiObject;
      AContext: IDeserializerContext): TValue; override;
  end;

function IfThen(AValue: Boolean; const ATrue: TColor; AFalse: TColor = clWhite): TColor; overload; inline;

function dpiValue(const AValue: Integer; ADpi: Integer): Integer;
implementation

uses
  Winapi.Windows,
  Winapi.ActiveX,
  Winapi.ShLwApi,
  Winapi.ShellApi,
  System.SysUtils,
  System.IOUtils,
  apiCore,
  apiWrappers,
  Neon.Core.Types,
  Neon.Core.Utils,
  Neon.Core.Attributes,
  Neon.Core.Persistence.JSON;

function dpiValue(const AValue: Integer; ADpi: Integer): Integer;
begin
  if ADpi <> 96 then
    Result := MulDiv(AValue, ADpi, 96)
  else
    Result := AValue;
end;

class procedure TUtilities.ShellExec(const AOperation, AFileName, AParameters: string);
var
  ExecInfo: TShellExecuteInfo;
  NeedUninitialize: Boolean;
begin
  Assert(AFileName <> '');

  NeedUninitialize := Succeeded(CoInitializeEx(nil, COINIT_APARTMENTTHREADED or COINIT_DISABLE_OLE1DDE));
  try
    FillChar(ExecInfo, SizeOf(ExecInfo), 0);
    ExecInfo.cbSize := SizeOf(ExecInfo);

    ExecInfo.Wnd := 0;
    ExecInfo.lpVerb := Pointer(AOperation);
    ExecInfo.lpFile := PChar(AFileName);
    ExecInfo.lpParameters := Pointer(AParameters);
    // ExecInfo.lpDirectory := Pointer(TPath.GetDirectoryName(AFileName));
    ExecInfo.nShow := SW_SHOWNORMAL;
    ExecInfo.fMask := SEE_MASK_NOASYNC or SEE_MASK_FLAG_NO_UI;
    {$IFDEF UNICODE}
    ExecInfo.fMask := ExecInfo.fMask or SEE_MASK_UNICODE;
    {$ENDIF}
    {$WARN SYMBOL_PLATFORM OFF}
    Win32Check(ShellExecuteEx(@ExecInfo));
    {$WARN SYMBOL_PLATFORM ON}
  finally
    if NeedUninitialize then
      CoUninitialize;
  end;
end;

class function TUtilities.CreateGUID: string;
var
  LTempGUID: TGUID;
begin
  System.SysUtils.CreateGUID(LTempGUID);
  Result := GUIDToString(LTempGUID);
end;

class function TUtilities.ValidURL(const URL: Widestring): Boolean;
begin
  Result := PathIsURL(PWideChar(URL));
end;

class function TUtilities.ValidItem(const AItem: TSettingItem): Boolean;
begin
  Result := False;
  case AItem.ItemType of
    App: Result := TFile.Exists(AItem.Path);
    URL: Result := ValidURL(AItem.Path) and AItem.Path.Contains('%s');
  end;

  Result := Result and not AItem.Param.IsEmpty and not AItem.Title.IsEmpty;
end;

class procedure TImageContainer.FromStream(AContainer: IAIMPImageContainer; const AStream: TStream);
begin
  AStream.Position := soFromBeginning;
  CheckResult(AContainer.SetDataSize(AStream.Size));
  AStream.ReadBuffer(AContainer.GetData^, AContainer.GetDataSize);
end;

class function TImageContainer.FromAppIcon(const AFileName: string; AContainer: IAIMPImageContainer): IAIMPImageContainer;
var
  LIcon: TIcon;
  LStream: TMemoryStream;
  VersionInfo: IAIMPServiceVersionInfo;
begin
  if not TFile.Exists(AFileName) or
    (CoreGetService(IID_IAIMPServiceVersionInfo, VersionInfo) and (VersionInfo.GetBuildNumber <= 1683))
  then
    Exit(nil);

  if Assigned(AContainer) then
    Result := AContainer
  else
    CheckResult(CoreIntf.CreateObject(IID_IAIMPImageContainer, Result));

  LIcon := TIcon.Create;
  try
    LIcon.Handle := ExtractIcon(HInstance, PWideChar(AFileName), 0);
    if LIcon.Handle <> 0 then
    begin
      LStream := TMemoryStream.Create;
      try
        LIcon.SaveToStream(LStream);
        FromStream(Result, LStream);
      finally
        FreeAndNil(LStream);
      end;
    end
    else
      Result := FromResource('icon_app', Result);
  finally
    FreeAndNil(LIcon);
  end;
end;

class function TImageContainer.FromResource(const AResName: string; AContainer: IAIMPImageContainer): IAIMPImageContainer;
var
  LStream: TResourceStream;
  VersionInfo: IAIMPServiceVersionInfo;
begin
  if CoreGetService(IID_IAIMPServiceVersionInfo, VersionInfo) and (VersionInfo.GetBuildNumber <= 1683) then
    Exit(nil);

  if Assigned(AContainer) then
    Result := AContainer
  else
    CheckResult(CoreIntf.CreateObject(IID_IAIMPImageContainer, Result));

  LStream := TResourceStream.Create(HInstance, AResName, 'PNG');
  try
    FromStream(Result, LStream);
  finally
    FreeAndNil(LStream);
  end;
end;

class function TImageContainer.FromImage(const AImage: IAIMPImage; AContainer: IAIMPImageContainer): IAIMPImageContainer;
var
  LStream: IAIMPMemoryStream;
begin
  if not Assigned(AImage) then
    Exit(nil);

  if Assigned(AContainer) then
    Result := AContainer
  else
    CheckResult(CoreIntf.CreateObject(IID_IAIMPImageContainer, Result));

  CheckResult(CoreIntf.CreateObject(IID_IAIMPMemoryStream, LStream));
  CheckResult(AImage.SaveToStream(LStream, AIMP_IMAGE_FORMAT_PNG));
  CheckResult(LStream.Seek(0, AIMP_STREAM_SEEKMODE_FROM_BEGINNING));
  CheckResult(Result.SetDataSize(LStream.GetSize));
  LStream.Read(Result.GetData, Result.GetDataSize);
end;

class function TImageContainer.ToStream(const AContainer: IAIMPImageContainer): TMemoryStream;
begin
  Result := TMemoryStream.Create;
  Result.WriteData(AContainer.GetData, AContainer.GetDataSize);
end;

class function TImageContainer.ToImage(const AContainer: IAIMPImageContainer; ASize: byte): IAIMPImage;
begin
  if not Assigned(AContainer) then
    Exit(nil);

  CheckResult(AContainer.CreateImage(Result));
  CheckResult(Result.Resize(ASize, ASize));
end;

function IfThen(AValue: Boolean; const ATrue: TColor; AFalse: TColor = clWhite): TColor;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

class function TImageContainerSerializer.CanHandle(AType: PTypeInfo): Boolean;
begin
  Result := AType = GetTargetInfo;
end;

class function TImageContainerSerializer.GetTargetInfo: PTypeInfo;
begin
  Result := TypeInfo(IAIMPImageContainer);
end;

function TImageContainerSerializer.Serialize(const AValue: TValue; ANeonObject: TNeonRttiObject;
  AContext: ISerializerContext): TJSONValue;
var
  LImageContainer: IAIMPImageContainer;
  LStream: TMemoryStream;
  LBase64: string;
begin
  LImageContainer := AValue.AsInterface as IAIMPImageContainer;

  if (LImageContainer = nil) or (LImageContainer.GetDataSize = 0) then
  begin
    case ANeonObject.NeonInclude.Value of
      IncludeIf.NotEmpty, IncludeIf.NotDefault:
        Exit(nil);
    else
      Exit(TJSONString.Create(''));
    end;
  end;

  LStream := TImageContainer.ToStream(LImageContainer);
  try
    LStream.Position := soFromBeginning;
    LBase64 := TBase64.Encode(LStream);
    Result := TJSONString.Create(LBase64);
  finally
    FreeAndNil(LStream);
  end;
end;

function TImageContainerSerializer.Deserialize(AValue: TJSONValue; const AData: TValue;
  ANeonObject: TNeonRttiObject; AContext: IDeserializerContext): TValue;
var
  LImageContainer: IAIMPImageContainer;
  LStream: TMemoryStream;
begin
  Result := nil;
  if AValue.Value.IsEmpty then
    Exit;

  if Succeeded(CoreIntf.CreateObject(IID_IAIMPImageContainer, LImageContainer)) then
  begin
    LStream := TMemoryStream.Create;
    try
      TBase64.Decode(AValue.Value, LStream);
      LStream.Position := soFromBeginning;
      TImageContainer.FromStream(LImageContainer, LStream);
      Result := TValue.From<IAIMPImageContainer>(LImageContainer);
    finally
      FreeAndNil(LStream);
    end;
  end;
end;

end.
