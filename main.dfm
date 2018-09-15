object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 336
  ClientWidth = 527
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  DesignSize = (
    527
    336)
  PixelsPerInch = 96
  TextHeight = 13
  object BRun: TButton
    Left = 216
    Top = 280
    Width = 75
    Height = 25
    Anchors = [akLeft, akBottom]
    Caption = 'Solve'
    TabOrder = 0
    OnClick = BRunClick
  end
  object Memo1: TMemo
    Left = 0
    Top = 0
    Width = 529
    Height = 257
    Anchors = [akLeft, akTop, akRight, akBottom]
    ScrollBars = ssBoth
    TabOrder = 1
  end
end
