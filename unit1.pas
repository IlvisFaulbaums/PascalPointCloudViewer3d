unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  OpenGLContext, GL, GLU, Math, Types;

type

  { TForm1 }

  TForm1 = class(TForm)
    OpenGLControl1: TOpenGLControl;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure OpenGLControl1MouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure OpenGLControl1Paint(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure OpenGLControl1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure OpenGLControl1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure OpenGLControl1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    procedure InitializeOpenGL;
    procedure DrawPoints;
    procedure LoadPointsFromFile(const FileName: string);
    procedure NormalizePoints;
    procedure CalculateCentroid;
  public
    ZoomDistance: GLfloat;
    MouseDownX, MouseDownY: Integer;
    IsDragging: Boolean;
    CameraAngleX, CameraAngleY: GLfloat;
    Centroid: array[0..2] of GLfloat;
  end;

var
  Form1: TForm1;
  Points: array of array[0..2] of GLfloat;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  LoadPointsFromFile('points.txt');
  NormalizePoints;
  CalculateCentroid;
  OpenGLControl1.MakeCurrent;
  InitializeOpenGL;
  Timer1.Interval := 30;
  Timer1.Enabled := True;
  IsDragging := False;
  CameraAngleX := 45.0;
  CameraAngleY := 45.0;
  ZoomDistance := 2.0; // Initial distance from the camera to the point cloud
  OpenGLControl1.Invalidate;
end;

// Add this event handler for the OnMouseWheel event of the OpenGLControl1 component
procedure TForm1.OpenGLControl1MouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
const
  ZoomSpeed = 0.001; // Adjust the speed of zooming
begin
  // Increase or decrease the distance from the camera to the point cloud
  ZoomDistance := ZoomDistance + WheelDelta * ZoomSpeed;
  Handled := True; // Prevent default handling of the mouse wheel event
  OpenGLControl1.Invalidate; // Trigger redraw
end;

procedure TForm1.InitializeOpenGL;
begin
  glClearColor(0.0, 0.0, 0.0, 0.0);
  glEnable(GL_DEPTH_TEST);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  gluPerspective(45.0, OpenGLControl1.Width / OpenGLControl1.Height, 0.1, 100.0);
  glMatrixMode(GL_MODELVIEW);
end;

// Update the gluLookAt call in the DrawPoints procedure
procedure TForm1.DrawPoints;
var
  i: Integer;
  EyeX, EyeY, EyeZ: GLfloat;
begin
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity();

  // Calculate the position of the camera
  EyeX := Centroid[0] + ZoomDistance * cos(DegToRad(CameraAngleX)) * cos(DegToRad(CameraAngleY));
  EyeY := Centroid[1] + ZoomDistance * sin(DegToRad(CameraAngleY));
  EyeZ := Centroid[2] + ZoomDistance * sin(DegToRad(CameraAngleX)) * cos(DegToRad(CameraAngleY));

  gluLookAt(EyeX, EyeY, EyeZ, Centroid[0], Centroid[1], Centroid[2], 0.0, 1.0, 0.0);

  // Draw points
  glBegin(GL_POINTS);
  for i := 0 to High(Points) do
  begin
    glVertex3f(Points[i][0], Points[i][1], Points[i][2]);
  end;
  glEnd();

  OpenGLControl1.SwapBuffers;
end;

procedure TForm1.OpenGLControl1Paint(Sender: TObject);
begin
  DrawPoints;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  OpenGLControl1.Invalidate;
end;

procedure TForm1.OpenGLControl1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    IsDragging := True;
    MouseDownX := X;
    MouseDownY := Y;
  end;
end;

procedure TForm1.OpenGLControl1MouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if IsDragging then
  begin
    // Adjust camera rotation based on mouse movement
    CameraAngleX := CameraAngleX + (X - MouseDownX) * 0.5; // Change the sign here to invert horizontal movement
    CameraAngleY := CameraAngleY + (Y - MouseDownY) * 0.5; // Change the sign here to invert vertical movement
    // Ensure the vertical angle stays within bounds
    if CameraAngleY > 89.0 then CameraAngleY := 89.0;
    if CameraAngleY < -89.0 then CameraAngleY := -89.0;
    // Update mouse position for next movement
    MouseDownX := X;
    MouseDownY := Y;
    // Trigger redraw
    OpenGLControl1.Invalidate;
  end;
end;



procedure TForm1.OpenGLControl1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    IsDragging := False;
  end;
end;

procedure TForm1.LoadPointsFromFile(const FileName: string);
var
  PointList: TStringList;
  i: Integer;
  PointData: TStringList;
begin
  PointList := TStringList.Create;
  PointData := TStringList.Create;
  try
    PointList.LoadFromFile(FileName);
    SetLength(Points, PointList.Count);
    for i := 0 to PointList.Count - 1 do
    begin
      PointData.Clear;
      PointData.Delimiter := ' ';
      PointData.DelimitedText := PointList[i];
      if PointData.Count = 3 then
      begin
        Points[i][0] := StrToFloat(PointData[0]);
        Points[i][1] := -StrToFloat(PointData[1]);
        Points[i][2] := StrToFloat(PointData[2]);
      end;
    end;
  finally
    PointData.Free;
    PointList.Free;
  end;
end;

procedure TForm1.NormalizePoints;
var
  MaxValue: GLfloat;
  i, j: Integer;
begin
  if Length(Points) = 0 then Exit;
  MaxValue := Abs(Points[0][0]);
  for i := 0 to High(Points) do
  begin
    for j := 0 to 2 do
    begin
      if Abs(Points[i][j]) > MaxValue then
        MaxValue := Abs(Points[i][j]);
    end;
  end;
  if MaxValue > 0 then
  begin
    for i := 0 to High(Points) do
    begin
      for j := 0 to 2 do
      begin
        Points[i][j] := Points[i][j] / MaxValue;
      end;
    end;
  end;
end;

procedure TForm1.CalculateCentroid;
var
  SumX, SumY, SumZ: GLfloat;
  i: Integer;
begin
  SumX := 0.0;
  SumY := 0.0;
  SumZ := 0.0;
  for i := 0 to High(Points) do
  begin
    SumX := SumX + Points[i][0];
    SumY := SumY + Points[i][1];
    SumZ := SumZ + Points[i][2];
  end;
  Centroid[0] := SumX / Length(Points);
  Centroid[1] := SumY / Length(Points);
  Centroid[2] := SumZ / Length(Points);
end;

end.

