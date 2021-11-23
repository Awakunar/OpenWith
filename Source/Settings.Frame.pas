unit Settings.Frame;

interface

uses
  Settings.Form,
  Winapi.Windows,
  apiObjects,
  apiOptions;

type
  TSettingsFrame = class(TInterfacedObject, IAIMPOptionsDialogFrame)
  private
    FForm: TSettingsForm;
    procedure HandlerModified(Sender: TObject);
  protected
    function CreateFrame(ParentWnd: HWND): HWND; stdcall;
    procedure DestroyFrame; stdcall;
    function GetName(out S: IAIMPString): HRESULT; stdcall;
    procedure Notification(ID: Integer); stdcall;
  end;

implementation

uses
  System.Sysutils,
  apiGUI,
  apiWrappers;

function TSettingsFrame.CreateFrame(ParentWnd: HWND): HWND;
var
  R: Trect;
  AService: IAIMPServiceUI;
begin
  Result := 0;

  if CoreGetService(IAIMPServiceUI, AService) then
  begin
    FForm := TSettingsForm.Create(ParentWnd, AService);
    FForm.OnModified := HandlerModified;
    GetWindowRect(ParentWnd, R);
    OffsetRect(R, -R.Left, -R.Top);
    FForm.Form.SetPlacement(TAIMPUIControlPlacement.Create(R));
    Result := FForm.Form.GetHandle;
  end;
end;

procedure TSettingsFrame.DestroyFrame;
begin
  if Assigned(FForm.Form) then
  begin
    FForm.Form.Release(False);
    FForm.Form := nil;
  end;

  if Assigned(FForm) then
    FForm := nil;
end;

function TSettingsFrame.GetName(out S: IAIMPString): HRESULT;
begin
  try
    S := MakeString('OpenWith');
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

procedure TSettingsFrame.Notification(ID: Integer);
begin
  if Assigned(FForm) then
    case ID of
      AIMP_SERVICE_OPTIONSDIALOG_NOTIFICATION_LOCALIZATION:
        TSettingsForm(FForm).ApplyLocalization;
      AIMP_SERVICE_OPTIONSDIALOG_NOTIFICATION_LOAD:
        TSettingsForm(FForm).ConfigLoad;
      AIMP_SERVICE_OPTIONSDIALOG_NOTIFICATION_SAVE:
        TSettingsForm(FForm).ConfigSave;
    end;
end;

procedure TSettingsFrame.HandlerModified(Sender: TObject);
var
  AServiceOptions: IAIMPServiceOptionsDialog;
begin
  if Supports(CoreIntf, IAIMPServiceOptionsDialog, AServiceOptions) then
    AServiceOptions.FrameModified(Self);
end;

end.
