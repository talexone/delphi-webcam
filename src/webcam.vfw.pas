unit webcam.vfw;

interface

uses Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, VFW;

type

  RVideoCapDevice= record
    szDeviceName: array[0..79] of Char;
    szDeviceVersion: array[0..79] of Char;
  end;

  Bytes = array of byte;
  PBytes = ^Bytes;
  TTabByte = array[0..0] of Byte;
  PTabByte = ^TTabByte;

  AImageIn= array of Byte;
  PAImageIn= ^AImageIn;
  Av_capability= array of RVideoCapDevice;

  TWebCam = class
    private
      AAv_capability: Av_capability;
      FHandle: Integer;
      WebCam: TPanel;
      FDestImage: TImage;
      FVideoBitmap: TBitmap;
      FOwner: TWinControl;
      fIsCameraConnected: boolean;
      fCallBackProc: Pointer;
      function ConnectWebCam(WebcamID:integer; AHandle: THandle; Rect: TRect):boolean;
      procedure CaptureWebCam(FilePath: String);
      procedure CloseWebcam();
      procedure CreateWebCamFrame();
      function FrameCallBackProc(HndPreview: HWND; lp: PVideoHdr): LongInt; stdcall;
    public
      constructor Create(Owner: TWinControl);
      destructor Destroy(); override;
      procedure LoadWebcamList(const Items: TStrings);
      procedure StartCapture(DeviceIndex: integer);
      procedure StopCapture();
      procedure CaptureImage(ABitmap: TBitmap);
      property IsCameraConnected: boolean read fIsCameraConnected;
  end;

  function MethodToProcedure (self       : TObject;
                            methodAddr : pointer) : pointer; overload;
  function MethodToProcedure (method     : TMethod) : pointer; overload;

implementation

constructor TWebCam.Create(Owner: TWinControl);
begin
  inherited Create;
  fOwner := Owner;
  fIsCameraConnected := false;
  fVideoBitmap := TBitmap.Create();
  fCallBackProc := MethodToProcedure(Self, @TWebCam.FrameCallBackProc);
end;

destructor TWebCam.Destroy();
begin
  VirtualFree(fCallBackProc, 0, MEM_RELEASE);
  fVideoBitmap.Free;
  if Assigned(WebCam) then WebCam.Free;
  inherited;
end;

procedure TWebCam.LoadWebcamList(const Items: TStrings);
var
  VideoCapDevice: RVideoCapDevice;
  I: Integer;
begin
  SetLength(AAv_capability, 0);
  for I:= 0 to 9 do begin
    if capGetDriverDescription(I, @VideoCapDevice.szDeviceName, sizeof(VideoCapDevice.szDeviceName), @VideoCapDevice.szDeviceVersion, sizeof(VideoCapDevice.szDeviceVersion)) then begin
      SetLength(AAv_capability, Length(AAv_capability)+ 1);
      AAv_capability[Length(AAv_capability)- 1]:= VideoCapDevice;
      Items.Append(VideoCapDevice.szDeviceName);
    end;
  end;
end;

procedure TWebCam.CaptureImage(ABitmap: TBitmap);
begin
  ABitmap.Assign(fVideoBitmap);
  capSetCallbackOnFrame(FHandle, nil);
  capGrabFrame(FHandle);
  fIsCameraConnected:= false;
  WebCam.Hide;
end;

function TWebCam.Connectwebcam(WebcamID:integer; AHandle: THandle; Rect: TRect):boolean;
var
  FDriverCaps: TCapDriverCaps;
begin
  if not IsCameraConnected then begin
    FHandle:= capCreateCaptureWindow(nil, WS_CHILD or WS_VISIBLE, Rect.Left, Rect.Top, Rect.Right - Rect.Left, Rect.Bottom - Rect.Top, AHandle, 0);
    if (FHandle<> 0) and capDriverConnect(FHandle, WebCamID) then begin
      if capDriverGetCaps(FHandle, @FDriverCaps, SizeOf(TCapDriverCaps)) then begin
        if FDriverCaps.fHasOverlay then
          capOverlay(FHandle, True)
        else begin
          capPreviewRate(FHandle, 33);
          capPreview(FHandle, True);
        end;
        fIsCameraConnected:= true;
      end;
    end;
  end;
end;

procedure TWebCam.CloseWebcam();
begin
  capCaptureStop(FHandle);
  capDriverDisconnect(FHandle);
  fIsCameraConnected:= false;
end;

procedure TWebCam.StartCapture(DeviceIndex: integer);
begin
  CreateWebCamFrame();
  ConnectWebCam(DeviceIndex, WebCam.Handle, Rect(0, 0, WebCam.Width, WebCam.Height));
  capSetCallbackOnFrame(FHandle, fCallBackProc);
end;

procedure TWebCam.StopCapture();
begin
  capSetCallbackOnFrame(FHandle, nil);
  capPreview(FHandle, FALSE);
  CloseWebCam();
end;

procedure TWebCam.CaptureWebCam(FilePath: String);
begin
//  if CaptureWindow <> 0 then begin
//  SendMessage(CaptureWindow, WM_CAP_GRAB_FRAME, 0, 0);
//  SendMessage(CaptureWindow, WM_CAP_SAVEDIB, 0, longint(pchar(FilePath)));
//  end;
end;

function TWebCam.FrameCallBackProc(HndPreview: HWND; lp: PVideoHdr): LongInt; stdcall;
var
  buffer: PTabByte;
  TempBitmapInfo: BITMAPINFO;
  x, y, linesize: integer;
  row: PTabByte;
begin
  buffer := Pointer(lp^.lpData);
  try
    capGetVideoFormat(FHandle,@TempBitmapInfo,sizeof(TempBitmapInfo));
    fVideoBitmap.Width := TempBitmapInfo.bmiHeader.biWidth;
    fVideoBitmap.Height := TempBitmapInfo.bmiHeader.biHeight;
    case TempBitmapInfo.bmiHeader.biBitCount of
      1: fVideoBitmap.PixelFormat := pf1bit;
      4: fVideoBitmap.PixelFormat := pf4bit;
      8: fVideoBitmap.PixelFormat := pf8bit;
      16: fVideoBitmap.PixelFormat := pf16bit;
      24: fVideoBitmap.PixelFormat := pf24bit;
    end;
    linesize := fVideoBitmap.Width * TempBitmapInfo.bmiHeader.biBitCount div 8;
    for y := 0 to fVideoBitmap.Height - 1 do
    begin
      row := fVideoBitmap.ScanLine[fVideoBitmap.Height - y - 1];
      for x := 0 to linesize - 1 do
        row[x] := buffer^[x + y * linesize];
    end;
  finally
  end;
end;

procedure TWebCam.CreateWebCamFrame();
begin
  if not Assigned(WebCam) then
    WebCam := TPanel.Create(FOwner);
  with WebCam do
  begin
    Parent := FOwner;
    Caption := '';
    Align := alClient;
    Visible := True;
    BringToFront;
  end;
end;

function MethodToProcedure(self: TObject; methodAddr: pointer) : pointer;
type
  TMethodToProc = packed record
    popEax   : byte;                  // $58      pop EAX
    pushSelf : record                 //          push self
                 opcode  : byte;      // $B8
                 self    : pointer;   // self
               end;
    pushEax  : byte;                  // $50      push EAX
    jump     : record                 //          jmp [target]
                 opcode  : byte;      // $FF
                 modRm   : byte;      // $25
                 pTarget : ^pointer;  // @target
                 target  : pointer;   //          @MethodAddr
               end;
  end;
var mtp : ^TMethodToProc absolute result;
begin
  mtp := VirtualAlloc(nil, sizeOf(mtp^), MEM_COMMIT, PAGE_EXECUTE_READWRITE);
  with mtp^ do begin
    popEax          := $58;
    pushSelf.opcode := $68;
    pushSelf.self   := self;
    pushEax         := $50;
    jump.opcode     := $FF;
    jump.modRm      := $25;
    jump.pTarget    := @jump.target;
    jump.target     := methodAddr;
  end;
end;

function MethodToProcedure(method: TMethod) : pointer;
begin
  result := MethodToProcedure(TObject(method.data), method.code);
end;


end.
