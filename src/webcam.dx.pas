unit webcam.dx;

interface

uses Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, VFrames, VSample, Direct3D9, DirectDraw, DirectShow9, DirectSound,
  DXTypes;


type
  TWebCam = class
    private
      fVideoImage : TVideoImage;
      fVideoBitmap: TBitmap;
      fCrossHair: boolean;
      fMirror: boolean;
      fOwner: TWinControl;
      fIsCameraConnected: boolean;
      fWebCam: TPaintBox;
      DeviceList : TStringList;
      procedure OnNewVideoFrame(Sender : TObject; Width, Height: integer; DataPtr: pointer);
      procedure CreateWebCamFrame();
    public
      constructor Create(Owner: TWinControl);
      destructor Destroy(); override;
      procedure LoadWebcamList(const Items: TStrings);
      procedure StartCapture(DeviceIndex: integer);
      procedure StopCapture();
      procedure CaptureImage(ABitmap: TBitmap);
      procedure CaptureProperties;
      property IsCameraConnected: boolean read fIsCameraConnected;
  end;

implementation

procedure TWebCam.CaptureProperties;
begin
  fVideoImage.ShowProperty_Stream;
end;

constructor TWebCam.Create(Owner: TWinControl);
begin
  inherited Create;
  fOwner := Owner;
  fCrossHair := false;
  fMirror := false;
  fIsCameraConnected := false;
  fVideoBitmap       := TBitmap.create;

  // Create instance of our video image class.
  fVideoImage        := TVideoImage.Create;
  // Tell fVideoImage what routine to call whan a new video-frame has arrived.
  // (This way we control painting by ourselves)
  fVideoImage.OnNewVideoFrame := OnNewVideoFrame;
end;

destructor TWebCam.Destroy();
begin
  fVideoImage.Free;
  fVideoBitmap.Free;
  FreeAndNil(fWebCam);
  inherited;
end;

procedure TWebCam.LoadWebcamList(const Items: TStrings);
begin
  // Get list of available cameras
  DeviceList := TStringList.Create;
  fVideoImage.GetListOfDevices(DeviceList);
  Items.Assign(DeviceList);
end;

procedure TWebCam.StartCapture(DeviceIndex: integer);
begin
  CreateWebCamFrame();
  fVideoImage.VideoStart(DeviceList[DeviceIndex]);
  fIsCameraConnected := True;
end;

procedure TWebCam.StopCapture();
begin
  fVideoImage.VideoStop;
end;

procedure TWebCam.CaptureImage(ABitmap: TBitmap);
begin
  ABitmap.Assign(fVideoBitmap);
  StopCapture();
  fIsCameraConnected:= false;
  fWebCam.Hide;
end;

procedure TWebCam.OnNewVideoFrame(Sender : TObject; Width, Height: integer; DataPtr: pointer);
var
  i, r : integer;
begin
  // Retreive latest video image
  fVideoImage.GetBitmap(fVideoBitmap);

  // Paint a crosshair onto video image
  IF fCrosshair then
    begin
      WITH fVideoBitmap.Canvas DO
        BEGIN
          Brush.Style := bsClear;
          Pen.Width   := 3;
          Pen.Color   := clRed;
          moveto(0, fVideoBitmap.Height div 2);
          lineto(fVideoBitmap.Width, fVideoBitmap.Height div 2);
          moveto(fVideoBitmap.Width div 2, 0);
          lineto(fVideoBitmap.Width div 2, fVideoBitmap.Height);
          FOR i := 1 TO 3 DO
            begin
              r := (fVideoBitmap.Height div 8) *i;
              ellipse(fVideoBitmap.Width div 2 -r, fVideoBitmap.Height div 2 -r,
                      fVideoBitmap.Width div 2 +r, fVideoBitmap.Height div 2 +r);
            end;
        END;
    end;

  // Paint image onto screen, either normally or flipped.
  IF fMirror
    then fWebCam.Canvas.CopyRect(Rect(0, 0, fVideoBitmap.Width, fVideoBitmap.height),
                                   fVideoBitmap.Canvas,
                                   Rect(fVideoBitmap.Width-1, 0, 0, fVideoBitmap.height))
    else fWebCam.Canvas.Draw(0, 0, fVideoBitmap);
end;

procedure TWebCam.CreateWebCamFrame();
begin
  if not Assigned(fWebCam) then
    fWebCam := TPaintBox.Create(FOwner);
  with fWebCam do
  begin
    Parent := FOwner;
    Align := alClient;
    Visible := True;
    BringToFront;
  end;
end;

end.
