unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.StrUtils, System.Generics.Collections, System.Math.Vectors, System.IOUtils,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Objects, FMX.Layouts, FMX.Ani,
  Schnapsen.Engine, Schnapsen.AI, Schnapsen.Net;

type
  TCardLoc = (clDeck, clHand, clTrick, clGone);

  TCardView = class(TControl)
  private
    FFlip: Single;
    FFrom, FTo: Boolean;
    procedure SetFlip(const Value: Single);
  protected
    procedure Paint; override;
    procedure Click; override;
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
  public
    Card: TCard;
    Dim, Playable: Boolean;
    Loc: TCardLoc;
    Seat: TSeat;
    Jitter, JX, JY: Single;
    StackIndex: Integer;
    HomeX, HomeY: Single;
    function FaceUp: Boolean;
    procedure TurnTo(Up: Boolean; Dur: Single = 0; Delay: Single = 0);
  published
    property Flip: Single read FFlip write SetFlip;
  end;

  TUIButton = class(TRectangle)
  protected
    procedure Click; override;
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
  public
    Action: TProc;
    BaseColor, HoverColor: TAlphaColor;
  end;

  TScheduled = record
    Due: Int64;
    Gen: Integer;
    Proc: TProc;
  end;

  TRole = (nrSolo, nrHost, nrClient);
  TSeatKind = (skAI, skHuman);

  TDecision = record
    Kind: Char;
    Seat: TSeat;
    Value: string;
  end;

  TWait = record
    Active: Boolean;
    Kind: Char;
    Seat: TSeat;
    Compute: TFunc<string>;
    Apply: TProc<string>;
  end;

  TGameForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    G: TGame;
    FReady, FTrumpKnown, FPlaying, FAwaitHuman, FResetScores: Boolean;
    Views: array[TCard] of TCardView;
    VisHand: array[TSeat] of TCards;
    FSteps: TArray<TDealStep>;
    FTrick: TList<TCardView>;
    FQueue: TList<TScheduled>;
    FGen: Integer;
    FTicker: TTimer;
    FPaused: Boolean;
    FPausedAt: Int64;
    CardW, CardH: Single;
    FScale, FVW, FVH: Single; // Bühnenmaßstab und virtuelle Größe
    Scores, Bummerl: array[0..1] of Integer;
    FDealer: TSeat;
    FBid: TContract;
    FBidDecl, FBidSeat: TSeat;
    FBidPasses: Integer;
    FMult: Integer;
    FBubbleId: array[TSeat] of Integer;
    FCardDone: TProc<string>;
    // Mehrspieler
    FMe: TSeat;
    FRole: TRole;
    FKind: array[TSeat] of TSeatKind;
    FNames: array[TSeat] of string;
    FSeatHuman, FAssigned: array[TSeat] of Boolean;
    FInbox: TList<TDecision>;
    FWait: TWait;
    FLinks: TList<TNetLink>;
    FHost: TNetLink;
    FServer: TNetServer;
    FInGame, FUseTcp, FAuto, FSeatGot: Boolean;
    FJoinId: Integer;
    FLogFile: string;
    // UI
    Avatars: array[TSeat] of TCircle;
    AvatarText: array[TSeat] of TText;
    LobbyOverlay: TUIButton;
    LobbyBox: TRectangle;
    LobbyContent: TLayout;
    LobbyStatus: TText;
    Felt: TRectangle;
    TableRing: TEllipse;
    Stage: TLayout;
    CardLayer, UILayer: TLayout;
    Plates: array[TSeat] of TRectangle;
    PlateName, PlateInfo: array[TSeat] of TText;
    Bubbles: array[TSeat] of TRectangle;
    BubbleText: array[TSeat] of TText;
    TrumpBox, ContractBox, ScoreBox, HintBox: TRectangle;
    TrumpSym, TrumpName, ContractName_, ContractSub, HintText, BummerlText: TText;
    ScoreVal: array[0..1] of TText;
    ScoreBar, ScoreTrack: array[0..1] of TRectangle;
    Panel: TRectangle;
    PanelTitle: TText;
    PanelButtons: TList<TUIButton>;
    Overlay: TUIButton;
    ResultBox: TRectangle;
    ResultTitle, ResultDetail: TText;
    ResultButton: TUIButton;
    RulesOverlay: TUIButton;
    RulesBox: TRectangle;
    BtnRules, BtnNew: TUIButton;
    // Hilfen
    procedure After(Ms: Integer; const P: TProc);
    procedure Tick(Sender: TObject);
    function MakeText(AParent: TFmxObject; const S: string; Size: Single; Color: TAlphaColor;
      Bold: Boolean = False; HAlign: TTextAlign = TTextAlign.Leading): TText;
    function MakeRect(AParent: TFmxObject; Fill: TAlphaColor; Radius: Single; Stroke: TAlphaColor = 0): TRectangle;
    function MakeButton(AParent: TFmxObject; const Caption, Sub: string; const R: TRectF;
      Base: TAlphaColor = $FF2A3542): TUIButton;
    procedure BuildUI;
    procedure LayoutAll;
    // Kartenlage
    function TableCenter: TPointF;
    function SortKey(C: TCard): Integer;
    function SortedHand(Seat: TSeat): TArray<TCard>;
    function HandSlot(Seat: TSeat; I, N: Integer; out A: Single): TPointF;
    function TrickSlot(Seat: TSeat): TPointF;
    function PlateCenter(Seat: TSeat): TPointF;
    procedure MoveView(V: TCardView; X, Y, A, Dur: Single; Delay: Single = 0);
    procedure PlaceCard(V: TCardView; Dur: Single = 0; Delay: Single = 0);
    procedure RelayoutHand(Seat: TSeat; Dur: Single);
    // Anzeige
    procedure Say(S: TSeat; const Msg: string);
    procedure Hint(const Msg: string);
    procedure SetActivePlate(S: Integer);
    procedure UpdatePlates;
    procedure UpdateHud;
    procedure UpdateScore;
    procedure Ask(const Title: string; const Caps, Subs: TArray<string>; const Done: TProc<Integer>);
    procedure HidePanel;
    procedure ShowOverlay(const Title, Detail, Button: string; const Next: TProc; Cancelable: Boolean = False);
    procedure Pause(On: Boolean);
    procedure ShowRules;
    // Sitzplätze
    function ViewOf(S: TSeat): TSeat;
    function SeatName(S: TSeat): string;
    function Verb(S: TSeat; const DuForm, ErForm: string): string;
    function MyTeam: Integer;
    procedure ApplySeatLook;
    // Mehrspieler
    procedure Publish(Kind: Char; Seat: TSeat; const Value: string; Skip: Integer);
    procedure Decide(Kind: Char; Seat: TSeat; DelayMs: Integer; const Compute: TFunc<string>;
      const AskLocal: TProc<TProc<string>>; const Apply: TProc<string>);
    procedure ComputeAsync(DelayMs: Integer; const Compute: TFunc<string>; const Done: TProc<string>);
    function ValidDecision(Kind: Char; Seat: TSeat; const Value: string): Boolean;
    procedure Enqueue(Kind: Char; Seat: TSeat; const Value: string);
    procedure ProcessInbox;
    procedure SeatLost(L: TNetLink);
    procedure ConnectionLost(const Why: string);
    procedure LeaveNetwork;
    // Lobby
    procedure ClearLobby;
    function LobbyText(const S: string; X, Y, W: Single; Size: Single; Color: TAlphaColor; Bold: Boolean): TText;
    function LobbyButton(const Caption, Sub: string; X, Y, W, H: Single; Color: TAlphaColor;
      const Action: TProc): TUIButton;
    procedure ShowLobby;
    procedure ShowSetupPage;
    procedure HostPressed;
    procedure ShowHostWaitPage;
    procedure HostLine(L: TNetLink; Line: string);
    procedure HostBegin;
    procedure HostBeginIfFull;
    procedure ShowJoinPage;
    procedure ShowDeviceList;
    procedure JoinDevice(const Dev, Address: string);
    procedure ClientLine(L: TNetLink; Line: string);
    procedure StartGame(Dealer: TSeat);
    procedure ConfirmMenu;
    // Ablauf
    procedure NewBummerl(Dealer: TSeat);
    procedure StartHand;
    procedure LayDeck;
    procedure DealRange(First, Last: Integer; const Done: TProc);
    procedure ChooseTrump;
    procedure SetTrump(T: TSuit);
    procedure StartBidding;
    procedure NextBid;
    procedure BidResult(Seat: TSeat; C: TContract; Speak: Boolean);
    procedure EndBidding;
    procedure SpritzenStep(Idx: Integer);
    procedure Spritzt(D: TSeat);
    procedure BeginPlay;
    procedure NextTurn;
    procedure DoPlay(C: TCard);
    procedure CollectTrick(W: TSeat);
    procedure EndHand;
    procedure ShowResult;
  public
    procedure CardClicked(V: TCardView);
  end;

var
  GameForm: TGameForm;

implementation

{$R *.fmx}

const
  ProtocolVersion = '1';
  TeamColor: array[0..1] of TAlphaColor = ($FFFFC107, $FF64B5F6);
  Gold = $FFFFD54F;
  PanelFill = $F0121A22;
  {$IFDEF MSWINDOWS}
  SymbolFont = 'Segoe UI Symbol';
  IndexFont = 'Georgia';
  {$ELSE}
  SymbolFont = '';
  IndexFont = '';
  {$ENDIF}

function SuitColor(S: TSuit): TAlphaColor;
begin
  if S in [suHerz, suKaro] then
    Result := $FFD32F2F
  else
    Result := $FF1B1B1F;
end;

function Lighter(C: TAlphaColor): TAlphaColor;
var
  R: TAlphaColorRec;
begin
  R.Color := C;
  R.R := Min(255, R.R + 24);
  R.G := Min(255, R.G + 24);
  R.B := Min(255, R.B + 24);
  R.A := Max(R.A, $E8);
  Result := R.Color;
end;

function Plural(N: Integer): string;
begin
  Result := IntToStr(N) + IfThen(N = 1, ' Punkt', ' Punkte');
end;

{ TCardView }

function TCardView.FaceUp: Boolean;
begin
  Result := FTo;
end;

procedure TCardView.SetFlip(const Value: Single);
begin
  FFlip := Value;
  Repaint;
end;

procedure TCardView.TurnTo(Up: Boolean; Dur, Delay: Single);
begin
  StopPropertyAnimation('Flip');
  if Dur <= 0 then
  begin
    FFrom := Up;
    FTo := Up;
    FFlip := 1;
    Repaint;
    Exit;
  end;
  if Up = FTo then
    Exit;
  FFrom := FTo;
  FTo := Up;
  FFlip := 0;
  Repaint;
  TAnimator.AnimateFloatDelay(Self, 'Flip', 1, Dur, Delay, TAnimationType.InOut, TInterpolationType.Sinusoidal);
end;

procedure TCardView.Click;
begin
  inherited;
  GameForm.CardClicked(Self);
end;

procedure TCardView.DoMouseEnter;
begin
  inherited;
  if Playable then
  begin
    StopPropertyAnimation('Position.Y');
    TAnimator.AnimateFloat(Self, 'Position.Y', HomeY - Height / 2 - Height * 0.14, 0.12,
      TAnimationType.Out, TInterpolationType.Quadratic);
  end;
  Repaint;
end;

procedure TCardView.DoMouseLeave;
begin
  inherited;
  if Loc = clHand then
  begin
    StopPropertyAnimation('Position.Y');
    TAnimator.AnimateFloat(Self, 'Position.Y', HomeY - Height / 2, 0.15,
      TAnimationType.Out, TInterpolationType.Quadratic);
  end;
  Repaint;
end;

// Zeichnet eine Karte (Vorder- oder Rückseite) einmalig in das Cache-Bitmap.
procedure RenderCard(Canvas: TCanvas; Card: TCard; Front: Boolean; W, H: Single);
var
  Rad, Op, Step: Single;
  Body, Inner, R: TRectF;
  Saved: TMatrix;
  S: TSuit;
  Rk: TRank;
  Col: TAlphaColor;
  X, Y: Single;
  Poly: TPolygon;
  I: Integer;

  procedure Txt(const Str: string; const Box: TRectF; Size: Single; Color: TAlphaColor;
    const Family: string; Bold: Boolean = False);
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := Color;
    Canvas.Font.Family := Family;
    Canvas.Font.Size := Size;
    if Bold then
      Canvas.Font.Style := [TFontStyle.fsBold]
    else
      Canvas.Font.Style := [];
    Canvas.FillText(Box, Str, False, Op, [], TTextAlign.Center, TTextAlign.Center);
  end;

  procedure Index;
  begin
    Txt(RankShort[Rk], RectF(W * 0.02, H * 0.02, W * 0.3, H * 0.02 + W * 0.26), W * 0.2, Col, IndexFont, True);
    Txt(SuitSymbol[S], RectF(W * 0.02, H * 0.02 + W * 0.22, W * 0.3, H * 0.02 + W * 0.44), W * 0.17, Col, SymbolFont);
  end;

const
  TenPips: array[0..9, 0..1] of Single = ((0.36, 0.19), (0.64, 0.19), (0.5, 0.3), (0.36, 0.41),
    (0.64, 0.41), (0.36, 0.59), (0.64, 0.59), (0.5, 0.7), (0.36, 0.81), (0.64, 0.81));
  FaceGlyph: array[rkBube..rkKoenig] of string = (#$265E, #$265B, #$265A);
begin
  Op := 1;
  Rad := W * 0.08;
  Saved := Canvas.Matrix;
  Body := RectF(2, 2, W - 4, H - 5); // Rand lassen: FMX invalidiert nur die Kontrollgrenzen

  // Schatten
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := $40000000;
  Canvas.FillRect(RectF(4, 5, W - 2, H - 2), Rad, Rad, AllCorners, Op);
  Canvas.Fill.Color := $22000000;
  Canvas.FillRect(RectF(3, 3.5, W - 3, H - 3.5), Rad, Rad, AllCorners, Op);

  S := SuitOf(Card);
  Rk := RankOf(Card);
  Col := SuitColor(S);
  if Front then
  begin
    Canvas.Fill.Kind := TBrushKind.Gradient;
    Canvas.Fill.Gradient.Style := TGradientStyle.Linear;
    Canvas.Fill.Gradient.Color := $FFFFFFFF;
    Canvas.Fill.Gradient.Color1 := $FFF0EADC;
    Canvas.FillRect(Body, Rad, Rad, AllCorners, Op);
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := $FFB9B09C;
    Canvas.Stroke.Thickness := 1;
    Canvas.DrawRect(Body, Rad, Rad, AllCorners, Op);

    Index;
    // gespiegelter Index unten rechts
    Canvas.SetMatrix(TMatrix.CreateTranslation(-W / 2, -H / 2) * TMatrix.CreateRotation(Pi) *
      TMatrix.CreateTranslation(W / 2 - 2, H / 2 - 3) * Canvas.Matrix);
    Index;
    Canvas.SetMatrix(Saved);

    case Rk of
      rkAss:
        Txt(SuitSymbol[S], RectF(0, H * 0.18, W - 2, H * 0.82), H * 0.4, Col, SymbolFont);
      rkZehn:
        for I := 0 to 9 do
        begin
          X := TenPips[I, 0] * W;
          Y := TenPips[I, 1] * H;
          Txt(SuitSymbol[S], RectF(X - W * 0.14, Y - H * 0.08, X + W * 0.14, Y + H * 0.08), H * 0.12, Col, SymbolFont);
        end;
    else
      Inner := RectF(W * 0.22, H * 0.13, W * 0.78, H * 0.87);
      Canvas.Fill.Kind := TBrushKind.Gradient;
      if S in [suHerz, suKaro] then
      begin
        Canvas.Fill.Gradient.Color := $FFFFF3EE;
        Canvas.Fill.Gradient.Color1 := $FFF6D9D2;
      end
      else
      begin
        Canvas.Fill.Gradient.Color := $FFF1F4FA;
        Canvas.Fill.Gradient.Color1 := $FFD9DFEC;
      end;
      Canvas.FillRect(Inner, W * 0.04, W * 0.04, AllCorners, Op);
      Canvas.Stroke.Color := $FFC9A227;
      Canvas.Stroke.Thickness := Max(1, W * 0.015);
      Canvas.DrawRect(Inner, W * 0.04, W * 0.04, AllCorners, Op);
      Txt(FaceGlyph[Rk], RectF(Inner.Left, Inner.Top + H * 0.04, Inner.Right, Inner.Top + H * 0.46),
        H * 0.3, Col, SymbolFont);
      Txt(SuitSymbol[S], RectF(Inner.Left, Inner.Top + H * 0.44, Inner.Right, Inner.Bottom - H * 0.04),
        H * 0.16, Col, SymbolFont);
    end;
  end
  else
  begin
    // Rückseite: weißer Rand, weinrotes Rautenmuster, goldenes Medaillon
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := $FFFBF8F1;
    Canvas.FillRect(Body, Rad, Rad, AllCorners, Op);
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := $FFB9B09C;
    Canvas.Stroke.Thickness := 1;
    Canvas.DrawRect(Body, Rad, Rad, AllCorners, Op);
    Inner := Body;
    Inner.Inflate(-W * 0.07, -W * 0.07);
    Canvas.Fill.Kind := TBrushKind.Gradient;
    Canvas.Fill.Gradient.Style := TGradientStyle.Linear;
    Canvas.Fill.Gradient.Color := $FFA3243A;
    Canvas.Fill.Gradient.Color1 := $FF5C0E1E;
    Canvas.FillRect(Inner, Rad * 0.6, Rad * 0.6, AllCorners, Op);
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := $26FFFFFF;
    Step := W * 0.11;
    SetLength(Poly, 4);
    Y := Inner.Top + Step * 0.6;
    while Y < Inner.Bottom - Step * 0.4 do
    begin
      X := Inner.Left + Step * 0.6;
      while X < Inner.Right - Step * 0.4 do
      begin
        Poly[0] := PointF(X, Y - Step * 0.36);
        Poly[1] := PointF(X + Step * 0.36, Y);
        Poly[2] := PointF(X, Y + Step * 0.36);
        Poly[3] := PointF(X - Step * 0.36, Y);
        Canvas.FillPolygon(Poly, Op);
        X := X + Step;
      end;
      Y := Y + Step;
    end;
    R := RectF(W / 2 - W * 0.2, H / 2 - W * 0.2, W / 2 + W * 0.2, H / 2 + W * 0.2);
    Canvas.Fill.Color := $FF7A1426;
    Canvas.FillEllipse(R, Op);
    Canvas.Stroke.Color := $FFD4AF37;
    Canvas.Stroke.Thickness := Max(1.5, W * 0.02);
    Canvas.DrawEllipse(R, Op);
    Canvas.Stroke.Thickness := 1;
    Canvas.Stroke.Color := $90D4AF37;
    Canvas.DrawRect(Inner, Rad * 0.6, Rad * 0.6, AllCorners, Op);
    Txt(#$2665, R, W * 0.2, $FFD4AF37, SymbolFont);
  end;
  Canvas.SetMatrix(Saved);
end;

var
  // Bild-Cache: 20 Vorderseiten + 1 Rückseite, neu erzeugt bei geänderter Kartengröße
  FaceCache: array[TCard] of TBitmap;
  BackCache: TBitmap;
  CacheW, CacheH, CacheScale: Single;

procedure FreeCardCache;
var
  C: TCard;
begin
  for C := Low(TCard) to High(TCard) do
    FreeAndNil(FaceCache[C]);
  FreeAndNil(BackCache);
end;

function CardBitmap(Card: TCard; Front: Boolean; W, H, Scale: Single): TBitmap;
var
  B: ^TBitmap;
begin
  if (W <> CacheW) or (H <> CacheH) or (Scale <> CacheScale) then
  begin
    FreeCardCache;
    CacheW := W;
    CacheH := H;
    CacheScale := Scale;
  end;
  if Front then
    B := @FaceCache[Card]
  else
    B := @BackCache;
  if B^ = nil then
  begin
    B^ := TBitmap.Create(Ceil(W * Scale), Ceil(H * Scale));
    B^.Clear(0);
    if B^.Canvas.BeginScene then
      try
        B^.Canvas.SetMatrix(TMatrix.CreateScaling(Scale, Scale));
        RenderCard(B^.Canvas, Card, Front, W, H);
      finally
        B^.Canvas.EndScene;
      end;
  end;
  Result := B^;
end;

procedure TCardView.Paint;
var
  W, H, SX, Op, Rad: Single;
  Saved: TMatrix;
  Front: Boolean;
  Bmp: TBitmap;
begin
  W := Width;
  H := Height;
  Op := AbsoluteOpacity;
  Rad := W * 0.08;
  SX := Abs(Cos(Pi * FFlip));
  Front := IfThen(FFlip < 0.5, Ord(FFrom), Ord(FTo)) = 1;
  Saved := Canvas.Matrix;
  if SX < 0.999 then // Umdrehen: horizontal um die Mitte stauchen
    Canvas.SetMatrix(TMatrix.CreateTranslation(-W / 2, 0) * TMatrix.CreateScaling(Max(SX, 0.02), 1) *
      TMatrix.CreateTranslation(W / 2, 0) * Saved);
  Bmp := CardBitmap(Card, Front, W, H, Canvas.Scale);
  Canvas.DrawBitmap(Bmp, RectF(0, 0, Bmp.Width, Bmp.Height), RectF(0, 0, W, H), Op, False);
  if Front and Dim then
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := $70101418;
    Canvas.FillRect(RectF(2, 2, W - 4, H - 5), Rad, Rad, AllCorners, Op);
  end;
  if Front and Playable and IsMouseOver then
  begin
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := Gold;
    Canvas.Stroke.Thickness := 3;
    Canvas.DrawRect(RectF(3, 3, W - 5, H - 6), Rad, Rad, AllCorners, Op);
  end;
  Canvas.SetMatrix(Saved);
end;

{ TUIButton }

procedure TUIButton.Click;
begin
  inherited;
  if Assigned(Action) then
    Action();
end;

procedure TUIButton.DoMouseEnter;
begin
  inherited;
  Fill.Color := HoverColor;
end;

procedure TUIButton.DoMouseLeave;
begin
  inherited;
  Fill.Color := BaseColor;
end;

{ TGameForm: Hilfen }

procedure TGameForm.After(Ms: Integer; const P: TProc);
var
  S: TScheduled;
begin
  S.Due := TThread.GetTickCount64 + Cardinal(Max(0, Ms));
  S.Gen := FGen;
  S.Proc := P;
  FQueue.Add(S);
end;

procedure TGameForm.Tick(Sender: TObject);
var
  Due: TArray<TScheduled>;
  Now: Int64;
  I: Integer;
begin
  if FPaused then
    Exit;
  Now := TThread.GetTickCount64;
  for I := FQueue.Count - 1 downto 0 do
    if FQueue[I].Due <= Now then
    begin
      Due := [FQueue[I]] + Due;
      FQueue.Delete(I);
    end;
  for I := 0 to High(Due) do
    if Due[I].Gen = FGen then
      Due[I].Proc();
end;

function TGameForm.MakeText(AParent: TFmxObject; const S: string; Size: Single; Color: TAlphaColor;
  Bold: Boolean; HAlign: TTextAlign): TText;
begin
  Result := TText.Create(Self);
  Result.Parent := AParent;
  Result.HitTest := False;
  Result.Text := S;
  Result.TextSettings.Font.Size := Size;
  Result.TextSettings.FontColor := Color;
  if Bold then
    Result.TextSettings.Font.Style := [TFontStyle.fsBold];
  Result.TextSettings.HorzAlign := HAlign;
  Result.TextSettings.VertAlign := TTextAlign.Center;
  Result.TextSettings.WordWrap := False;
end;

function TGameForm.MakeRect(AParent: TFmxObject; Fill: TAlphaColor; Radius: Single; Stroke: TAlphaColor): TRectangle;
begin
  Result := TRectangle.Create(Self);
  Result.Parent := AParent;
  Result.HitTest := False;
  Result.Fill.Color := Fill;
  Result.XRadius := Radius;
  Result.YRadius := Radius;
  if Stroke = 0 then
    Result.Stroke.Kind := TBrushKind.None
  else
  begin
    Result.Stroke.Color := Stroke;
    Result.Stroke.Thickness := 1;
  end;
end;

function TGameForm.MakeButton(AParent: TFmxObject; const Caption, Sub: string; const R: TRectF;
  Base: TAlphaColor): TUIButton;
var
  T: TText;
begin
  Result := TUIButton.Create(Self);
  Result.Parent := AParent;
  Result.SetBounds(R.Left, R.Top, R.Width, R.Height);
  Result.XRadius := 12;
  Result.YRadius := 12;
  Result.BaseColor := Base;
  Result.HoverColor := Lighter(Base);
  Result.Fill.Color := Base;
  Result.Stroke.Color := $40FFFFFF;
  Result.Cursor := crHandPoint;
  if Sub = '' then
  begin
    T := MakeText(Result, Caption, 16, $FFFFFFFF, True, TTextAlign.Center);
    T.Align := TAlignLayout.Contents;
  end
  else
  begin
    T := MakeText(Result, Caption, IfThen(Length(Caption) > 16, 13.5, 15), $FFFFFFFF, True, TTextAlign.Center);
    T.SetBounds(4, R.Height * 0.12, R.Width - 8, R.Height * 0.48);
    T := MakeText(Result, Sub, 12, $FFB8C4CE, False, TTextAlign.Center);
    T.SetBounds(4, R.Height * 0.56, R.Width - 8, R.Height * 0.32);
  end;
end;

{ Aufbau }

procedure TGameForm.FormCreate(Sender: TObject);
var
  C: TCard;
begin
  FQueue := TList<TScheduled>.Create;
  FTrick := TList<TCardView>.Create;
  PanelButtons := TList<TUIButton>.Create;
  BuildUI;
  for C := Low(TCard) to High(TCard) do
  begin
    Views[C] := TCardView.Create(Self);
    Views[C].Parent := CardLayer;
    Views[C].Card := C;
    Views[C].Visible := False;
    Views[C].TurnTo(False);
  end;
  FTicker := TTimer.Create(Self);
  FTicker.Interval := 15;
  FTicker.OnTimer := Tick;
  {$IFDEF ANDROID}
  FullScreen := True; // Statusleiste am Handy ausblenden
  {$ENDIF}
  FInbox := TList<TDecision>.Create;
  FLinks := TList<TNetLink>.Create;
  FReady := True;
  LayoutAll;
  // Testschalter: -tcp (lokal statt Bluetooth), -auto (KI spielt für dich), -log <Datei>,
  // -host (alle drei Plätze Menschen, sofort hosten), -join (sofort lokal beitreten)
  FUseTcp := FindCmdLineSwitch('tcp');
  FAuto := FindCmdLineSwitch('auto');
  FindCmdLineSwitch('log', FLogFile);
  ShowLobby;
  if FindCmdLineSwitch('host') then
  begin
    FSeatHuman[1] := True;
    FSeatHuman[2] := True;
    FSeatHuman[3] := True;
    HostPressed;
  end
  else if FindCmdLineSwitch('join') then
    JoinDevice('Lokaler Test (TCP)', '');
end;

procedure TGameForm.BuildUI;
var
  S: TSeat;
  T: Integer;
  Av: TCircle;
  Txt: TText;
begin
  Felt := MakeRect(Self, $FF145A36, 0);
  Felt.Align := TAlignLayout.Contents;
  Felt.Fill.Kind := TBrushKind.Gradient;
  Felt.Fill.Gradient.Style := TGradientStyle.Radial;
  Felt.Fill.Gradient.Color := $FF0A2E1C;
  Felt.Fill.Gradient.Color1 := $FF1F7A4A;

  Stage := TLayout.Create(Self);
  Stage.Parent := Self;
  Stage.HitTest := False;
  TableRing := TEllipse.Create(Self);
  TableRing.Parent := Stage;
  TableRing.HitTest := False;
  TableRing.Fill.Kind := TBrushKind.None;
  TableRing.Stroke.Color := $1EFFFFFF;
  TableRing.Stroke.Thickness := 2;

  CardLayer := TLayout.Create(Self);
  CardLayer.Parent := Stage;
  CardLayer.Align := TAlignLayout.Contents;
  CardLayer.HitTest := False;
  UILayer := TLayout.Create(Self);
  UILayer.Parent := Stage;
  UILayer.Align := TAlignLayout.Contents;
  UILayer.HitTest := False;

  for S := Low(TSeat) to High(TSeat) do
  begin
    Plates[S] := MakeRect(UILayer, $C8121A22, 14, $30FFFFFF);
    Plates[S].SetBounds(0, 0, 226, 58);
    Av := TCircle.Create(Self);
    Av.Parent := Plates[S];
    Av.HitTest := False;
    Av.SetBounds(9, 9, 40, 40);
    Av.Fill.Color := TeamColor[TeamOf(S)];
    Av.Stroke.Kind := TBrushKind.None;
    Avatars[S] := Av;
    AvatarText[S] := MakeText(Av, '', 18, $FF15202A, True, TTextAlign.Center);
    AvatarText[S].Align := TAlignLayout.Contents;
    PlateName[S] := MakeText(Plates[S], '', 16, $FFFFFFFF, True);
    PlateName[S].SetBounds(58, 7, 160, 24);
    PlateInfo[S] := MakeText(Plates[S], '', 12, $FFAEBBC6);
    PlateInfo[S].SetBounds(58, 31, 164, 20);

    Bubbles[S] := MakeRect(UILayer, $FFFFFFFF, 14);
    Bubbles[S].SetBounds(0, 0, 160, 40);
    Bubbles[S].Visible := False;
    BubbleText[S] := MakeText(Bubbles[S], '', 15, $FF15202A, True, TTextAlign.Center);
    BubbleText[S].Align := TAlignLayout.Contents;
  end;

  TrumpBox := MakeRect(UILayer, $C8121A22, 14, $30FFFFFF);
  TrumpBox.SetBounds(14, 14, 230, 66);
  TrumpSym := MakeText(TrumpBox, '?', 36, $FFFFFFFF, False, TTextAlign.Center);
  TrumpSym.TextSettings.Font.Family := SymbolFont;
  TrumpSym.SetBounds(6, 4, 56, 58);
  Txt := MakeText(TrumpBox, 'TRUMPF', 11, $FF8FA0AE, True);
  Txt.SetBounds(68, 10, 150, 16);
  TrumpName := MakeText(TrumpBox, 'noch nicht gerufen', 17, $FFFFFFFF, True);
  TrumpName.SetBounds(68, 28, 156, 26);

  ContractBox := MakeRect(UILayer, $C8121A22, 14, $30FFFFFF);
  ContractBox.SetBounds(14, 88, 230, 58);
  Txt := MakeText(ContractBox, 'SPIEL', 11, $FF8FA0AE, True);
  Txt.SetBounds(14, 6, 200, 16);
  ContractName_ := MakeText(ContractBox, '–', 16, $FFFFFFFF, True);
  ContractName_.SetBounds(14, 20, 210, 22);
  ContractSub := MakeText(ContractBox, '', 12, Gold);
  ContractSub.SetBounds(14, 38, 210, 16);

  ScoreBox := MakeRect(UILayer, $C8121A22, 14, $30FFFFFF);
  ScoreBox.Width := 250;
  ScoreBox.Height := 118;
  Txt := MakeText(ScoreBox, 'BUMMERL  ·  BIS 24', 11, $FF8FA0AE, True);
  Txt.SetBounds(16, 8, 220, 16);
  for T := 0 to 1 do
  begin
    Txt := MakeText(ScoreBox, IfThen(T = 0, 'Wir', 'Sie'), 15, TeamColor[T], True);
    Txt.SetBounds(16, 30 + T * 30, 40, 22);
    ScoreTrack[T] := MakeRect(ScoreBox, $33FFFFFF, 4);
    ScoreTrack[T].SetBounds(58, 38 + T * 30, 120, 8);
    ScoreBar[T] := MakeRect(ScoreTrack[T], TeamColor[T], 4);
    ScoreBar[T].SetBounds(0, 0, 0, 8);
    ScoreVal[T] := MakeText(ScoreBox, '0', 15, $FFFFFFFF, True, TTextAlign.Trailing);
    ScoreVal[T].SetBounds(180, 30 + T * 30, 54, 22);
  end;
  BummerlText := MakeText(ScoreBox, '', 12, $FFAEBBC6);
  BummerlText.SetBounds(16, 90, 220, 18);

  HintBox := MakeRect(UILayer, $B0121A22, 16);
  HintBox.Height := 34;
  HintBox.Visible := False;
  HintText := MakeText(HintBox, '', 14, $FFFFFFFF, True, TTextAlign.Center);
  HintText.Align := TAlignLayout.Contents;

  BtnRules := MakeButton(UILayer, 'Regeln', '', RectF(0, 0, 110, 38), $D0263240);
  BtnRules.Action := ShowRules;
  BtnNew := MakeButton(UILayer, 'Menü', '', RectF(0, 0, 110, 38), $D0263240);
  BtnNew.Action := ConfirmMenu;

  Panel := MakeRect(UILayer, PanelFill, 18, $40FFFFFF);
  Panel.Visible := False;
  PanelTitle := MakeText(Panel, '', 18, $FFFFFFFF, True, TTextAlign.Center);

  Overlay := TUIButton.Create(Self);
  Overlay.Parent := UILayer;
  Overlay.Align := TAlignLayout.Contents;
  Overlay.BaseColor := $99000000;
  Overlay.HoverColor := $99000000;
  Overlay.Fill.Color := $99000000;
  Overlay.Stroke.Kind := TBrushKind.None;
  Overlay.Visible := False;
  ResultBox := MakeRect(Overlay, PanelFill, 22, $50FFD54F);
  ResultBox.HitTest := True; // Klicks in der Box sollen nicht als "daneben" zählen
  ResultBox.SetBounds(0, 0, 520, 270);
  ResultTitle := MakeText(ResultBox, '', 30, Gold, True, TTextAlign.Center);
  ResultTitle.SetBounds(20, 22, 480, 44);
  ResultDetail := MakeText(ResultBox, '', 15, $FFE3E9EE, False, TTextAlign.Center);
  ResultDetail.TextSettings.WordWrap := True;
  ResultDetail.TextSettings.VertAlign := TTextAlign.Leading;
  ResultDetail.SetBounds(30, 78, 460, 110);
  ResultButton := MakeButton(ResultBox, 'Weiter', '', RectF(170, 200, 350, 248), $FF2E7D4F);

  RulesOverlay := TUIButton.Create(Self);
  RulesOverlay.Parent := UILayer;
  RulesOverlay.Align := TAlignLayout.Contents;
  RulesOverlay.BaseColor := $B0000000;
  RulesOverlay.HoverColor := $B0000000;
  RulesOverlay.Fill.Color := $B0000000;
  RulesOverlay.Stroke.Kind := TBrushKind.None;
  RulesOverlay.Visible := False;
  RulesOverlay.Action := procedure
    begin
      RulesOverlay.Visible := False;
      Pause(False);
    end;
  RulesBox := MakeRect(RulesOverlay, PanelFill, 22, $50FFD54F);
  RulesBox.SetBounds(0, 0, 820, 640);

  LobbyOverlay := TUIButton.Create(Self);
  LobbyOverlay.Parent := UILayer;
  LobbyOverlay.Align := TAlignLayout.Contents;
  LobbyOverlay.BaseColor := $C8000000;
  LobbyOverlay.HoverColor := $C8000000;
  LobbyOverlay.Fill.Color := $C8000000;
  LobbyOverlay.Stroke.Kind := TBrushKind.None;
  LobbyBox := MakeRect(LobbyOverlay, PanelFill, 22, $50FFD54F);
  LobbyBox.HitTest := True;
  LobbyBox.SetBounds(0, 0, 584, 556);
  LobbyContent := TLayout.Create(Self);
  LobbyContent.Parent := LobbyBox;
  LobbyContent.Align := TAlignLayout.Contents;
end;

procedure TGameForm.FormDestroy(Sender: TObject);
begin
  FTicker.Enabled := False;
  LeaveNetwork; // koppelt die Links ab, damit eingereihte Netz-Callbacks nichts mehr auslösen
end;

procedure TGameForm.FormResize(Sender: TObject);
begin
  if FReady then
    LayoutAll;
end;

procedure TGameForm.LayoutAll;
var
  C: TCard;
  S: TSeat;
  P: TPointF;
  W, H: Single;
begin
  // Alles liegt auf einer Bühne mit virtueller Mindestgröße 1000×640, die auf kleinen Displays
  // gleichmäßig verkleinert wird; am PC (≥ 1000×640) bleibt der Maßstab 1.
  FScale := Min(1, Min(ClientWidth / 1000, ClientHeight / 640));
  FVW := ClientWidth / FScale;
  FVH := ClientHeight / FScale;
  Stage.Scale.X := FScale;
  Stage.Scale.Y := FScale;
  Stage.SetBounds(0, 0, FVW, FVH);
  W := FVW;
  H := FVH;
  CardW := Min(W / 9.2, H / 6.7);
  CardH := CardW * 1.45;
  P := TableCenter;
  TableRing.SetBounds(P.X - W * 0.3, P.Y - H * 0.3, W * 0.6, H * 0.6);
  for C := Low(TCard) to High(TCard) do
  begin
    Views[C].SetBounds(0, 0, CardW, CardH);
    if Views[C].Visible then
      PlaceCard(Views[C]);
  end;
  for S := Low(TSeat) to High(TSeat) do
  begin
    P := PlateCenter(S);
    Plates[S].Position.Point := PointF(P.X - Plates[S].Width / 2, P.Y - Plates[S].Height / 2);
  end;
  ScoreBox.Position.Point := PointF(W - ScoreBox.Width - 14, 14);
  BtnNew.Position.Point := PointF(W - BtnNew.Width - 14, H - 52);
  BtnRules.Position.Point := PointF(W - BtnNew.Width - BtnRules.Width - 24, H - 52);
  HintBox.Position.Y := H - CardH * 1.28 - 44;
  HintBox.Position.X := (W - HintBox.Width) / 2;
  if Panel.Visible then
    Panel.Position.Point := PointF((W - Panel.Width) / 2, TableCenter.Y - Panel.Height / 2);
  ResultBox.Position.Point := PointF((W - ResultBox.Width) / 2, (H - ResultBox.Height) / 2);
  RulesBox.Position.Point := PointF((W - RulesBox.Width) / 2, Max(10, (H - RulesBox.Height) / 2));
  LobbyBox.Position.Point := PointF((W - LobbyBox.Width) / 2, Max(10, (H - LobbyBox.Height) / 2));
end;

{ Kartenlage }

function TGameForm.TableCenter: TPointF;
begin
  Result := PointF(FVW / 2, FVH / 2 - CardH * 0.1);
end;

function TGameForm.SortKey(C: TCard): Integer;
const
  BaseOrder: array[TSuit] of Integer = (0, 2, 1, 3); // abwechselnd schwarz/rot
var
  S: Integer;
begin
  S := BaseOrder[SuitOf(C)];
  if FTrumpKnown and (not FPlaying or HasTrump(G.Contract)) and (SuitOf(C) = G.Trump) then
    S := -1;
  Result := S * 10 - CardStrength(G, C);
end;

function TGameForm.SortedHand(Seat: TSeat): TArray<TCard>;
var
  C, T: TCard;
  I, J: Integer;
begin
  Result := [];
  for C in VisHand[Seat] do
    Result := Result + [C];
  for I := 1 to High(Result) do
  begin
    T := Result[I];
    J := I - 1;
    while (J >= 0) and (SortKey(Result[J]) > SortKey(T)) do
    begin
      Result[J + 1] := Result[J];
      Dec(J);
    end;
    Result[J + 1] := T;
  end;
end;

function TGameForm.HandSlot(Seat: TSeat; I, N: Integer; out A: Single): TPointF;
var
  T, W, H: Single;
begin
  T := I - (N - 1) / 2;
  W := FVW;
  H := FVH;
  case ViewOf(Seat) of
    0: begin
         Result := PointF(W / 2 + T * CardW * 0.8, H - CardH * 0.6 + Sqr(T) * CardH * 0.025);
         A := T * 3.5;
       end;
    1: begin
         Result := PointF(CardH * 0.4, TableCenter.Y + T * CardW * 0.42);
         A := 90 + T * 3;
       end;
    2: begin
         Result := PointF(W / 2 - T * CardW * 0.42, CardH * 0.4);
         A := 180 - T * 3;
       end;
  else
    Result := PointF(W - CardH * 0.4, TableCenter.Y - T * CardW * 0.42);
    A := -90 - T * 3;
  end;
end;

function TGameForm.TrickSlot(Seat: TSeat): TPointF;
var
  C: TPointF;
begin
  C := TableCenter;
  case ViewOf(Seat) of
    0: Result := PointF(C.X, C.Y + CardH * 0.34);
    1: Result := PointF(C.X - CardW * 0.72, C.Y);
    2: Result := PointF(C.X, C.Y - CardH * 0.34);
  else
    Result := PointF(C.X + CardW * 0.72, C.Y);
  end;
end;

function TGameForm.PlateCenter(Seat: TSeat): TPointF;
var
  W, H: Single;
begin
  W := FVW;
  H := FVH;
  case ViewOf(Seat) of
    0: Result := PointF(Max(127, W / 2 - CardW * 2.2 - 135), H - 44);
    1: Result := PointF(127, TableCenter.Y + CardW * 1.45 + 36);
    2: Result := PointF(W / 2, CardH * 0.9 + 36);
  else
    Result := PointF(W - 127, TableCenter.Y + CardW * 1.45 + 36);
  end;
end;

procedure TGameForm.MoveView(V: TCardView; X, Y, A, Dur, Delay: Single);
begin
  V.StopPropertyAnimation('Position.X');
  V.StopPropertyAnimation('Position.Y');
  V.StopPropertyAnimation('RotationAngle');
  if Dur <= 0 then
  begin
    V.Position.Point := PointF(X - CardW / 2, Y - CardH / 2);
    V.RotationAngle := A;
    Exit;
  end;
  TAnimator.AnimateFloatDelay(V, 'Position.X', X - CardW / 2, Dur, Delay, TAnimationType.Out, TInterpolationType.Cubic);
  TAnimator.AnimateFloatDelay(V, 'Position.Y', Y - CardH / 2, Dur, Delay, TAnimationType.Out, TInterpolationType.Cubic);
  TAnimator.AnimateFloatDelay(V, 'RotationAngle', A, Dur, Delay, TAnimationType.Out, TInterpolationType.Cubic);
end;

procedure TGameForm.PlaceCard(V: TCardView; Dur, Delay: Single);
var
  P: TPointF;
  A: Single;
  Arr: TArray<TCard>;
  I, K: Integer;
begin
  case V.Loc of
    clDeck:
      begin
        P := TableCenter + PointF(-V.StackIndex * 0.5, -V.StackIndex * 0.5);
        A := V.Jitter;
      end;
    clHand:
      begin
        Arr := SortedHand(V.Seat);
        K := 0;
        for I := 0 to High(Arr) do
          if Arr[I] = V.Card then
            K := I;
        P := HandSlot(V.Seat, K, Length(Arr), A);
      end;
    clTrick:
      begin
        P := TrickSlot(V.Seat) + PointF(V.JX, V.JY);
        A := V.Jitter;
      end;
  else
    Exit;
  end;
  V.HomeX := P.X;
  V.HomeY := P.Y;
  MoveView(V, P.X, P.Y, A, Dur, Delay);
end;

procedure TGameForm.RelayoutHand(Seat: TSeat; Dur: Single);
var
  C: TCard;
begin
  for C in SortedHand(Seat) do
  begin
    Views[C].BringToFront;
    PlaceCard(Views[C], Dur);
  end;
end;

{ Anzeige }

procedure TGameForm.Say(S: TSeat; const Msg: string);
var
  B: TRectangle;
  Id: Integer;
  P: TPointF;
begin
  B := Bubbles[S];
  BubbleText[S].Text := Msg;
  B.Width := Max(90, Length(Msg) * 9.5 + 34);
  P := PlateCenter(S);
  case ViewOf(S) of
    0: P := PointF(P.X, P.Y - 62);
    1: P := PointF(P.X, P.Y - 62);
    2: P := PointF(P.X + 113 + B.Width / 2 + 10, P.Y);
  else
    P := PointF(P.X, P.Y - 62);
  end;
  B.Position.Point := PointF(Min(Max(8, P.X - B.Width / 2), FVW - B.Width - 8), P.Y - B.Height / 2);
  B.StopPropertyAnimation('Opacity');
  B.Opacity := 0;
  B.Visible := True;
  TAnimator.AnimateFloat(B, 'Opacity', 1, 0.18);
  Inc(FBubbleId[S]);
  Id := FBubbleId[S];
  After(1900,
    procedure
    begin
      if FBubbleId[S] = Id then
        TAnimator.AnimateFloat(B, 'Opacity', 0, 0.35);
    end);
end;

procedure TGameForm.Hint(const Msg: string);
begin
  HintBox.Visible := Msg <> '';
  HintText.Text := Msg;
  HintBox.Width := Length(Msg) * 8.2 + 48;
  HintBox.Position.X := (FVW - HintBox.Width) / 2;
end;

procedure TGameForm.SetActivePlate(S: Integer);
var
  P: TSeat;
begin
  for P := Low(TSeat) to High(TSeat) do
    if P = S then
    begin
      Plates[P].Stroke.Color := Gold;
      Plates[P].Stroke.Thickness := 2.5;
    end
    else
    begin
      Plates[P].Stroke.Color := $30FFFFFF;
      Plates[P].Stroke.Thickness := 1;
    end;
end;

procedure TGameForm.UpdatePlates;
var
  S: TSeat;
  Parts: TArray<string>;
begin
  for S := Low(TSeat) to High(TSeat) do
  begin
    Parts := [];
    if S = G.Dealer then
      Parts := Parts + ['Geber'];
    if S = G.Rufer then
      Parts := Parts + ['Rufer'];
    if FPlaying then
    begin
      if (S = G.Declarer) and (G.Contract <> ctNormal) then
        Parts := Parts + ['Ansager'];
      if not G.Active[S] then
        Parts := Parts + ['pausiert']
      else
        Parts := Parts + [IntToStr(G.TricksWon[S]) + IfThen(G.TricksWon[S] = 1, ' Stich', ' Stiche')];
    end;
    PlateInfo[S].Text := string.Join(' · ', Parts);
    Plates[S].Opacity := IfThen(FPlaying and not G.Active[S], 0.5, 1);
  end;
end;

procedure TGameForm.UpdateHud;
begin
  if not FTrumpKnown then
  begin
    TrumpSym.Text := '?';
    TrumpSym.TextSettings.FontColor := $FFFFFFFF;
    TrumpName.Text := 'noch nicht gerufen';
  end
  else
  begin
    TrumpSym.Text := SuitSymbol[G.Trump];
    TrumpSym.TextSettings.FontColor := IfThen(G.Trump in [suHerz, suKaro], $FFFF6B6B, $FFFFFFFF);
    if FPlaying and not HasTrump(G.Contract) then
      TrumpName.Text := 'kein Trumpf'
    else
      TrumpName.Text := SuitName[G.Trump];
  end;
  if not FPlaying then
  begin
    ContractName_.Text := IfThen(FTrumpKnown, 'Ansagen …', '–');
    ContractSub.Text := '';
  end
  else
  begin
    ContractName_.Text := ContractName[G.Contract];
    if G.Contract = ctNormal then
      ContractSub.Text := 'Rufer: ' + SeatName(G.Rufer)
    else
      ContractSub.Text := 'Ansager: ' + SeatName(G.Declarer);
    if G.Multiplier > 1 then
      ContractSub.Text := ContractSub.Text + '  ·  gespritzt ×' + IntToStr(G.Multiplier);
  end;
end;

procedure TGameForm.UpdateScore;
var
  R, T: Integer;
begin
  // Zeile 0 = eigenes Team („Wir“), Zeile 1 = Gegner
  for R := 0 to 1 do
  begin
    T := IfThen(R = 0, MyTeam, 1 - MyTeam);
    ScoreVal[R].Text := IntToStr(Scores[T]);
    ScoreBar[R].StopPropertyAnimation('Width');
    TAnimator.AnimateFloat(ScoreBar[R], 'Width', ScoreTrack[R].Width * Min(1, Scores[T] / 24), 0.5,
      TAnimationType.Out, TInterpolationType.Cubic);
  end;
  BummerlText.Text := Format('Gewonnene Bummerl:  Wir %d  ·  Sie %d', [Bummerl[MyTeam], Bummerl[1 - MyTeam]]);
end;

procedure TGameForm.Ask(const Title: string; const Caps, Subs: TArray<string>; const Done: TProc<Integer>);
var
  I, Cols, Rows: Integer;
  BW, BH, Gap, PW, PH: Single;
  B: TUIButton;

  function Choice(Idx: Integer): TProc;
  begin
    Result := procedure
      begin
        HidePanel;
        After(0,
          procedure
          begin
            Done(Idx);
          end);
      end;
  end;

begin
  for B in PanelButtons do
    B.Free;
  PanelButtons.Clear;
  Cols := Min(Length(Caps), 4);
  Rows := (Length(Caps) + Cols - 1) div Cols;
  BW := 186;
  BH := 58;
  Gap := 10;
  PW := Cols * BW + (Cols - 1) * Gap + 40;
  PH := 66 + Rows * BH + (Rows - 1) * Gap + 20;
  Panel.SetBounds((FVW - PW) / 2, TableCenter.Y - PH / 2, PW, PH);
  PanelTitle.SetBounds(20, 14, PW - 40, 36);
  PanelTitle.Text := Title;
  for I := 0 to High(Caps) do
  begin
    B := MakeButton(Panel, Caps[I], Subs[I],
      TRectF.Create(PointF(20 + (I mod Cols) * (BW + Gap), 60 + (I div Cols) * (BH + Gap)), BW, BH));
    B.Action := Choice(I);
    PanelButtons.Add(B);
  end;
  Panel.StopPropertyAnimation('Opacity');
  Panel.Opacity := 0;
  Panel.Visible := True;
  TAnimator.AnimateFloat(Panel, 'Opacity', 1, 0.2);
end;

procedure TGameForm.HidePanel;
begin
  Panel.Visible := False;
end;

procedure TGameForm.Pause(On: Boolean);
var
  I: Integer;
  S: TScheduled;
begin
  if On = FPaused then
    Exit;
  if On then
    FPausedAt := TThread.GetTickCount64
  else
    for I := 0 to FQueue.Count - 1 do
    begin
      S := FQueue[I];
      Inc(S.Due, Int64(TThread.GetTickCount64) - FPausedAt);
      FQueue[I] := S;
    end;
  FPaused := On;
end;


procedure TGameForm.ShowOverlay(const Title, Detail, Button: string; const Next: TProc; Cancelable: Boolean);
begin
  ResultTitle.Text := Title;
  ResultDetail.Text := Detail;
  TText(ResultButton.Children[0]).Text := Button;
  ResultButton.Action := procedure
    begin
      Overlay.Visible := False;
      Pause(False);
      After(0, Next);
    end;
  if Cancelable then
    Overlay.Action := procedure
      begin
        Overlay.Visible := False;
        Pause(False);
      end
  else
    Overlay.Action := nil;
  Overlay.Opacity := 0;
  Overlay.Visible := True;
  Overlay.BringToFront;
  TAnimator.AnimateFloat(Overlay, 'Opacity', 1, 0.25);
end;

procedure TGameForm.ShowRules;
var
  C: TContract;
  Y: Single;
  T: TText;
begin
  if RulesBox.ChildrenCount = 0 then
  begin
    T := MakeText(RulesBox, 'Bauernschnapsen – Regeln', 22, Gold, True);
    T.SetBounds(28, 16, 600, 34);
    T := MakeText(RulesBox,
      'Du spielst mit deinem Partner (gegenüber) gegen die zwei Gegner. 20 Karten (A 11, 10 10, K 4, D 3, B 2 Augen), ' +
      'je 5 pro Spieler. Der Rufer (links vom Geber) sieht 3 Karten und ruft Trumpf. Es gilt Farb- und ' +
      'Stichzwang: Farbe bedienen und wenn möglich überstechen, sonst trumpfen. Danach darf reihum ' +
      'ein höheres Spiel angesagt werden. Die Gegner des Ansagers dürfen spritzen (×2), der Ansager ' +
      'retour (×4). 20/40 werden automatisch angesagt, wenn du König oder Dame eines Paares ausspielst. ' +
      'Wer zuerst 24 Punkte hat, gewinnt das Bummerl (Schneider zählt doppelt).', 13, $FFE3E9EE);
    T.TextSettings.WordWrap := True;
    T.TextSettings.VertAlign := TTextAlign.Leading;
    T.SetBounds(28, 56, 764, 100);
    Y := 160;
    for C := Low(TContract) to High(TContract) do
    begin
      T := MakeText(RulesBox, ContractName[C], 14, $FFFFFFFF, True);
      T.SetBounds(28, Y, 200, 34);
      T := MakeText(RulesBox, Plural(ContractValue[C]), 13, Gold, True);
      T.SetBounds(224, Y, 80, 34);
      T := MakeText(RulesBox, ContractRule[C], 12.5, $FFC9D3DB);
      T.TextSettings.WordWrap := True;
      T.SetBounds(306, Y, 490, 34);
      Y := Y + 36;
    end;
    T := MakeText(RulesBox, 'Klicken zum Schließen', 12, $FF8FA0AE, False, TTextAlign.Center);
    T.SetBounds(0, Y + 6, 820, 20);
    RulesBox.Height := Y + 36;
    LayoutAll;
  end;
  Pause(True);
  RulesOverlay.Opacity := 0;
  RulesOverlay.Visible := True;
  RulesOverlay.BringToFront;
  TAnimator.AnimateFloat(RulesOverlay, 'Opacity', 1, 0.2);
end;

{ Sitzplätze und Namen }

function TGameForm.ViewOf(S: TSeat): TSeat;
begin
  Result := (S - FMe + 4) mod 4; // eigener Platz immer unten
end;

function TGameForm.SeatName(S: TSeat): string;
begin
  if S = FMe then
    Result := 'Du'
  else
    Result := FNames[S];
end;

function TGameForm.Verb(S: TSeat; const DuForm, ErForm: string): string;
begin
  if S = FMe then
    Result := DuForm
  else
    Result := ErForm;
end;

function TGameForm.MyTeam: Integer;
begin
  Result := TeamOf(FMe);
end;

procedure TGameForm.ApplySeatLook;
var
  S: TSeat;
begin
  for S := Low(TSeat) to High(TSeat) do
  begin
    PlateName[S].Text := SeatName(S);
    AvatarText[S].Text := UpperCase(Copy(FNames[S], 1, 1));
    Avatars[S].Fill.Color := TeamColor[Ord(TeamOf(S) <> MyTeam)];
  end;
  LayoutAll;
end;

{ Mehrspieler: alle Geräte rechnen dieselbe Engine, ausgetauscht werden nur Entscheidungen.
  Der Host mischt und rechnet die KI; jeder Mensch entscheidet auf seinem eigenen Gerät. }

function DeckToStr(const Deck: TArray<TCard>): string;
var
  C: TCard;
begin
  Result := '';
  for C in Deck do
    Result := Result + IfThen(Result = '', '', ',') + IntToStr(C);
end;

function ParseDeck(const S: string; out Deck: TArray<TCard>): Boolean;
var
  Parts: TArray<string>;
  Seen: TCards;
  I, V: Integer;
begin
  Parts := S.Split([',']);
  Result := Length(Parts) = 20;
  if not Result then
    Exit;
  SetLength(Deck, 20);
  Seen := [];
  for I := 0 to 19 do
  begin
    V := StrToIntDef(Parts[I], -1);
    if (V < 0) or (V > 19) or (V in Seen) then
      Exit(False);
    Include(Seen, V);
    Deck[I] := V;
  end;
end;

procedure TGameForm.Publish(Kind: Char; Seat: TSeat; const Value: string; Skip: Integer);
var
  Msg: string;
  L: TNetLink;
begin
  Msg := 'D|' + Kind + '|' + IntToStr(Seat) + '|' + Value;
  case FRole of
    nrHost:
      for L in FLinks do
        if (L.Seat >= 0) and (L.Seat <> Skip) then
          L.Send(Msg);
    nrClient:
      if (Seat = FMe) and (FHost <> nil) then
        FHost.Send(Msg);
  end;
end;

procedure TGameForm.Decide(Kind: Char; Seat: TSeat; DelayMs: Integer; const Compute: TFunc<string>;
  const AskLocal: TProc<TProc<string>>; const Apply: TProc<string>);
begin
  if (Seat = FMe) and Assigned(AskLocal) and not FAuto then
    AskLocal(
      procedure(V: string)
      begin
        Publish(Kind, Seat, V, -1);
        Apply(V);
      end)
  else if ((Seat = FMe) and Assigned(AskLocal)) or
    ((FRole <> nrClient) and (not Assigned(AskLocal) or (FKind[Seat] = skAI))) then
    ComputeAsync(DelayMs, Compute,
      procedure(V: string)
      begin
        Publish(Kind, Seat, V, -1);
        Apply(V);
      end)
  else
  begin
    FWait.Active := True;
    FWait.Kind := Kind;
    FWait.Seat := Seat;
    FWait.Compute := Compute;
    FWait.Apply := Apply;
    ProcessInbox;
  end;
end;

// KI rechnet im Hintergrund, damit Animationen flüssig bleiben. Der Spielzustand ändert sich
// nicht, solange der Ablauf auf diese Entscheidung wartet; das Ergebnis kommt frühestens nach
// DelayMs (natürliche Denkpause) und wird verworfen, wenn inzwischen neu gestartet wurde.
procedure TGameForm.ComputeAsync(DelayMs: Integer; const Compute: TFunc<string>; const Done: TProc<string>);
var
  Gen: Integer;
  Started: UInt64;
begin
  Gen := FGen;
  Started := TThread.GetTickCount64;
  TThread.CreateAnonymousThread(
    procedure
    var
      V: string;
      Ok: Boolean;
    begin
      try
        V := Compute();
        Ok := True;
      except
        Ok := False; // z. B. Spielzustand wurde durch Neustart ersetzt
      end;
      TThread.Queue(nil,
        procedure
        begin
          if Gen <> FGen then
            Exit;
          if not Ok then
            V := Compute(); // Rückfall im Hauptthread, damit der Ablauf nie hängen bleibt
          After(Max(0, DelayMs - Integer(TThread.GetTickCount64 - Started)),
            procedure
            begin
              Done(V);
            end);
        end);
    end).Start;
end;

function TGameForm.ValidDecision(Kind: Char; Seat: TSeat; const Value: string): Boolean;
var
  V: Integer;
  Deck: TArray<TCard>;
begin
  V := StrToIntDef(Value, -1);
  case Kind of
    'D': Result := ParseDeck(Value, Deck);
    'T': Result := (V >= 0) and (V <= 4);
    'B': Result := (V = 0) or ((V > 0) and (V <= Ord(High(TContract))) and
      (TContract(V) in AllowedBids(G, Seat, FBid, FBidDecl)));
    'S', 'R': Result := (V = 0) or (V = 1);
    'C': Result := (V >= 0) and (V <= 19) and (G.Turn = Seat) and (TCard(V) in LegalMoves(G));
  else
    Result := False;
  end;
end;

procedure TGameForm.Enqueue(Kind: Char; Seat: TSeat; const Value: string);
var
  M: TDecision;
begin
  M.Kind := Kind;
  M.Seat := Seat;
  M.Value := Value;
  FInbox.Add(M);
  ProcessInbox;
end;

procedure TGameForm.ProcessInbox;
var
  M: TDecision;
  Apply: TProc<string>;
  L: TNetLink;
begin
  if not FWait.Active or (FInbox.Count = 0) then
    Exit;
  M := FInbox[0];
  FInbox.Delete(0);
  if (M.Kind <> FWait.Kind) or (M.Seat <> FWait.Seat) or not ValidDecision(M.Kind, M.Seat, M.Value) then
  begin
    if FRole = nrHost then
    begin
      for L in FLinks do
        if L.Seat = M.Seat then
        begin
          L.Close;
          SeatLost(L); // ungültiger Zug: Verbindung trennen, KI übernimmt
          Exit;
        end;
    end
    else
      ConnectionLost('Das Spiel ist aus dem Takt geraten (ungültige Nachricht).');
    Exit;
  end;
  FWait.Active := False;
  Apply := FWait.Apply;
  if FRole = nrHost then
    Publish(M.Kind, M.Seat, M.Value, M.Seat);
  Apply(M.Value);
end;

procedure TGameForm.SeatLost(L: TNetLink);
var
  S: Integer;
begin
  S := L.Seat;
  L.Seat := -1;
  FLinks.Remove(L);
  if S < 0 then
    Exit;
  if not FInGame then
  begin
    FAssigned[S] := False;
    ShowHostWaitPage;
    Exit;
  end;
  FKind[S] := skAI;
  FNames[S] := FNames[S] + ' (KI)';
  ApplySeatLook;
  Say(S, 'Verbindung weg – KI übernimmt');
  if FWait.Active and (FWait.Seat = S) then
    After(300,
      procedure
      var
        V: string;
        Apply: TProc<string>;
      begin
        if not FWait.Active or (FWait.Seat <> S) then
          Exit;
        FWait.Active := False;
        Apply := FWait.Apply;
        V := FWait.Compute();
        Publish(FWait.Kind, S, V, -1);
        Apply(V);
      end);
end;

procedure TGameForm.ConnectionLost(const Why: string);
begin
  if FRole <> nrClient then
    Exit;
  LeaveNetwork;
  Inc(FGen);
  FQueue.Clear;
  ShowOverlay('Verbindung getrennt', Why, 'Zum Menü', ShowLobby);
end;

procedure TGameForm.LeaveNetwork;
var
  L: TNetLink;
begin
  if FServer <> nil then
    FServer.Stop; // shortcut: Serverobjekt bleibt bestehen, sein Accept-Thread prüft es noch
  FServer := nil;
  for L in FLinks do
  begin
    L.OnClosed := nil;
    L.Close;
  end;
  FLinks.Clear;
  if FHost <> nil then
  begin
    FHost.OnClosed := nil;
    FHost.Close;
  end;
  FHost := nil;
  FRole := nrSolo;
  FInGame := False;
  FSeatGot := False;
  Inc(FJoinId);
  FInbox.Clear;
  FWait.Active := False;
end;

{ Lobby }

procedure TGameForm.ClearLobby;
begin
  while LobbyContent.ChildrenCount > 0 do
    LobbyContent.Children[0].Free;
end;

function TGameForm.LobbyText(const S: string; X, Y, W: Single; Size: Single; Color: TAlphaColor;
  Bold: Boolean): TText;
begin
  Result := MakeText(LobbyContent, S, Size, Color, Bold);
  Result.TextSettings.WordWrap := True;
  Result.SetBounds(X, Y, W, Size * 2.2);
end;

function TGameForm.LobbyButton(const Caption, Sub: string; X, Y, W, H: Single; Color: TAlphaColor;
  const Action: TProc): TUIButton;
begin
  Result := MakeButton(LobbyContent, Caption, Sub, RectF(X, Y, X + W, Y + H), Color);
  Result.Action := procedure
    begin
      After(0, Action); // nicht im eigenen Click-Handler freigeben
    end;
end;

procedure TGameForm.ShowLobby;
begin
  LeaveNetwork;
  Inc(FGen);
  FQueue.Clear;
  Pause(False);
  HidePanel;
  Overlay.Visible := False;
  Hint('');
  LobbyOverlay.Visible := True;
  LobbyOverlay.BringToFront;
  ShowSetupPage;
end;

procedure TGameForm.ShowSetupPage;
const
  RowSeat: array[0..2] of TSeat = (2, 1, 3);
  RowName: array[0..2] of string = ('Partner (gegenüber)', 'Gegner links', 'Gegner rechts');
  Sel = $FF2E7D4F;
  Off = $FF2A3542;
var
  R: Integer;
  S: TSeat;
  L: TAILevel;

  function SetKind(Seat: TSeat; Human: Boolean): TProc;
  begin
    Result := procedure
      begin
        FSeatHuman[Seat] := Human;
        ShowSetupPage;
      end;
  end;

  function SetLevel(Lv: TAILevel): TProc;
  begin
    Result := procedure
      begin
        AILevel := Lv;
        ShowSetupPage;
      end;
  end;

begin
  ClearLobby;
  LobbyText('Bauernschnapsen', 32, 22, 500, 28, Gold, True);
  LobbyText('Wer sitzt mit dir am Tisch?', 32, 64, 500, 14, $FFAEBBC6, False);
  for R := 0 to 2 do
  begin
    S := RowSeat[R];
    LobbyText(RowName[R], 32, 112 + R * 58, 230, 15, $FFFFFFFF, True);
    LobbyButton('KI', '', 280, 102 + R * 58, 130, 44, IfThen(FSeatHuman[S], Off, Sel), SetKind(S, False));
    LobbyButton('Mensch', '', 420, 102 + R * 58, 130, 44, IfThen(FSeatHuman[S], Sel, Off), SetKind(S, True));
  end;
  LobbyText('Stärke der KI', 32, 300, 230, 15, $FFFFFFFF, True);
  for L := Low(TAILevel) to High(TAILevel) do
    LobbyButton(AILevelName[L], '', 32 + Ord(L) * 176, 330, 166, 44, IfThen(AILevel = L, Sel, Off), SetLevel(L));
  LobbyText('„Mensch“: Mitspieler verbinden sich per Bluetooth mit derselben App. ' +
    'Koppelt die Geräte vorher in den Bluetooth-Einstellungen.', 32, 392, 520, 12.5, $FF8FA0AE, False).Height := 40;
  LobbyStatus := LobbyText('', 32, 432, 520, 13, $FFFF8A80, True);
  LobbyButton('Spiel starten', 'als Gastgeber', 32, 472, 255, 58, $FF2E7D4F, HostPressed);
  LobbyButton('Spiel beitreten', 'bei einem anderen Gerät', 297, 472, 255, 58, $FF1E5A8A, ShowJoinPage);
end;

procedure TGameForm.HostPressed;
var
  S: TSeat;
  Any: Boolean;
  Why: string;
begin
  FMe := 0;
  FNames[0] := 'Du';
  FNames[1] := 'Franz';
  FNames[2] := 'Resi';
  FNames[3] := 'Sepp';
  Any := False;
  for S := Low(TSeat) to High(TSeat) do
  begin
    FKind[S] := skAI;
    FAssigned[S] := False;
    if (S <> 0) and FSeatHuman[S] then
      Any := True;
  end;
  FKind[0] := skHuman;
  if not Any then
  begin
    FRole := nrSolo;
    StartGame(TSeat(Random(4)));
    Exit;
  end;
  EnsureBluetoothPermission(
    procedure
    begin
      if not FUseTcp and not BluetoothAvailable(Why) then
      begin
        LobbyStatus.Text := Why;
        Exit;
      end;
      FNames[0] := LocalPlayerName(FUseTcp);
      try
        FServer := StartServer(FUseTcp,
          procedure(L: TNetLink)
          begin
            FLinks.Add(L);
            L.OnLine := HostLine;
            L.OnClosed := procedure(X: TNetLink)
              begin
                SeatLost(X);
              end;
            L.Start;
          end);
      except
        on E: Exception do
        begin
          LobbyStatus.Text := 'Bluetooth-Server startet nicht: ' + E.Message;
          Exit;
        end;
      end;
      FRole := nrHost;
      ShowHostWaitPage;
    end,
    procedure
    begin
      LobbyStatus.Text := 'Ohne Bluetooth-Berechtigung geht kein Mehrspieler.';
    end);
end;

procedure TGameForm.ShowHostWaitPage;
const
  RoleName: array[TSeat] of string = ('', 'Gegner links', 'Partner', 'Gegner rechts');
var
  S: TSeat;
  Y: Single;
  Open: Integer;
begin
  ClearLobby;
  LobbyText('Warte auf Mitspieler …', 32, 22, 520, 26, Gold, True);
  LobbyText('Auf den anderen Geräten: App öffnen → „Spiel beitreten“ → dieses Gerät wählen.',
    32, 66, 520, 13, $FFAEBBC6, False).Height := 40;
  Y := 120;
  Open := 0;
  for S := 1 to 3 do
    if FSeatHuman[S] then
    begin
      if FAssigned[S] then
        LobbyText(RoleName[S] + ':  ' + FNames[S] + '  ✓', 32, Y, 520, 16, $FF81C784, True)
      else
      begin
        LobbyText(RoleName[S] + ':  noch frei', 32, Y, 520, 16, $FFFFFFFF, False);
        Inc(Open);
      end;
      Y := Y + 40;
    end;
  LobbyStatus := LobbyText('', 32, 400, 520, 13, $FFFF8A80, True);
  LobbyButton('Jetzt starten', IfThen(Open > 0, 'freie Plätze spielt die KI', 'alle da'), 32, 472, 255, 58,
    $FF2E7D4F, HostBegin);
  LobbyButton('Abbrechen', '', 297, 472, 255, 58, $FF4A2A2A, ShowLobby);
  if Open = 0 then
    After(900, HostBeginIfFull);
end;

procedure TGameForm.HostLine(L: TNetLink; Line: string);
const
  JoinOrder: array[0..2] of TSeat = (2, 1, 3);
var
  P: TArray<string>;
  I: Integer;
  S: TSeat;
begin
  P := Line.Split(['|']);
  if Length(P) = 0 then
    Exit;
  if (P[0] = 'HELLO') and (L.Seat < 0) then
  begin
    if (Length(P) < 3) or (P[1] <> ProtocolVersion) or FInGame then
    begin
      L.Send('FULL');
      L.Close;
      FLinks.Remove(L);
      Exit;
    end;
    for I := 0 to 2 do
    begin
      S := JoinOrder[I];
      if FSeatHuman[S] and not FAssigned[S] then
      begin
        FAssigned[S] := True;
        FKind[S] := skHuman;
        FNames[S] := Copy(P[2], 1, 16);
        L.Seat := S;
        L.Send('SEAT|' + IntToStr(S));
        ShowHostWaitPage;
        Exit;
      end;
    end;
    L.Send('FULL');
    L.Close;
    FLinks.Remove(L);
  end
  else if (P[0] = 'D') and (Length(P) = 4) and FInGame and (L.Seat >= 0) then
  begin
    if (Length(P[1]) = 1) and (StrToIntDef(P[2], -1) = L.Seat) then
      Enqueue(P[1][1], L.Seat, P[3]);
  end;
end;

// Automatischer Start: erst unmittelbar davor prüfen, ob noch alle Menschen da sind
// (in den 900 ms bis hierher kann sich jemand getrennt haben).
procedure TGameForm.HostBeginIfFull;
var
  S: TSeat;
begin
  for S := 1 to 3 do
    if FSeatHuman[S] and not FAssigned[S] then
      Exit;
  HostBegin;
end;

procedure TGameForm.HostBegin;
var
  S: TSeat;
  Dealer: TSeat;
  L: TNetLink;
  Msg: string;
begin
  if (FRole <> nrHost) or FInGame then
    Exit;
  for S := 1 to 3 do
    if not FAssigned[S] then
      FKind[S] := skAI;
  Dealer := TSeat(Random(4));
  Msg := 'START|' + IntToStr(Dealer);
  for S := Low(TSeat) to High(TSeat) do
    Msg := Msg + '|' + FNames[S];
  for L in FLinks do
    if L.Seat >= 0 then
      L.Send(Msg);
  StartGame(Dealer);
end;

procedure TGameForm.ShowDeviceList;
var
  Devs: TArray<TPairedDevice>;
  Why: string;
  I: Integer;

  function Connect(const D: TPairedDevice): TProc;
  begin
    Result := procedure
      begin
        JoinDevice(D.Name, D.Address);
      end;
  end;

begin
  if FUseTcp then
  begin
    SetLength(Devs, 1);
    Devs[0].Name := 'Lokaler Test (TCP)';
    Devs[0].Address := '';
  end
  else if not BluetoothAvailable(Why) then
  begin
    LobbyStatus.Text := Why;
    Exit;
  end
  else
    Devs := PairedDevices;
  LobbyText('Wähle das Gerät des Gastgebers (gekoppelte Geräte):', 32, 66, 520, 13, $FFAEBBC6, False);
  if Length(Devs) = 0 then
    LobbyStatus.Text := 'Keine gekoppelten Geräte. Bitte zuerst in den Bluetooth-Einstellungen koppeln.';
  // Adressende anzeigen, damit gleich benannte Handys unterscheidbar sind
  for I := 0 to Min(High(Devs), 7) do
    LobbyButton(Devs[I].Name, Copy(Devs[I].Address, Length(Devs[I].Address) - 7, 8),
      32 + (I mod 2) * 265, 100 + (I div 2) * 66, 255, 56, $FF2A3542, Connect(Devs[I]));
end;

procedure TGameForm.ShowJoinPage;
begin
  ClearLobby;
  LobbyText('Spiel beitreten', 32, 22, 520, 26, Gold, True);
  LobbyStatus := LobbyText('', 32, 432, 520, 13, $FFFF8A80, True);
  LobbyButton('Zurück', '', 297, 472, 255, 58, $FF2A3542, ShowSetupPage);
  EnsureBluetoothPermission(ShowDeviceList,
    procedure
    begin
      LobbyStatus.Text := 'Ohne Bluetooth-Berechtigung geht kein Mehrspieler.';
    end);
end;

procedure TGameForm.JoinDevice(const Dev, Address: string);
var
  Id: Integer;
begin
  if LobbyStatus <> nil then
  begin
    LobbyStatus.TextSettings.FontColor := $FFAEBBC6;
    LobbyStatus.Text := 'Verbinde mit ' + Dev + ' …';
  end;
  Inc(FJoinId);
  Id := FJoinId;
  EnsureBluetoothPermission(
    procedure
    begin
      ConnectAsync(FUseTcp, Address,
        procedure(L: TNetLink; Err: string)
        begin
          // veralteter Versuch (inzwischen zurück, neu verbunden oder App beendet)
          if (Id <> FJoinId) or not LobbyOverlay.Visible or (FRole <> nrSolo) then
          begin
            if L <> nil then
              L.Close;
            Exit;
          end;
          if L = nil then
          begin
            ShowJoinPage;
            LobbyStatus.Text := 'Verbindung fehlgeschlagen: ' + Err;
            Exit;
          end;
          FHost := L;
          FRole := nrClient;
          L.OnLine := ClientLine;
          L.OnClosed := procedure(X: TNetLink)
            begin
              if FInGame then
                ConnectionLost('Die Verbindung zum Gastgeber ist abgebrochen.')
              else
              begin
                LeaveNetwork;
                ShowJoinPage;
                LobbyStatus.Text := 'Die Verbindung wurde getrennt.';
              end;
            end;
          L.Start;
          L.Send('HELLO|' + ProtocolVersion + '|' + LocalPlayerName(FUseTcp));
          ClearLobby;
          LobbyText('Verbunden', 32, 22, 520, 26, Gold, True);
          LobbyStatus := LobbyText('Warte auf den Gastgeber …', 32, 70, 520, 15, $FFFFFFFF, False);
          LobbyButton('Abbrechen', '', 297, 472, 255, 58, $FF4A2A2A, ShowLobby);
        end);
    end,
    procedure
    begin
      LobbyStatus.Text := 'Ohne Bluetooth-Berechtigung geht kein Mehrspieler.';
    end);
end;

procedure TGameForm.ClientLine(L: TNetLink; Line: string);
const
  RoleName: array[TSeat] of string = ('', 'Gegner links vom Gastgeber', 'Partner des Gastgebers',
    'Gegner rechts vom Gastgeber');
var
  P: TArray<string>;
  S: Integer;
begin
  P := Line.Split(['|']);
  if Length(P) = 0 then
    Exit;
  if (P[0] = 'SEAT') and (Length(P) = 2) then
  begin
    S := StrToIntDef(P[1], -1);
    if (S < 1) or (S > 3) then
      Exit;
    FMe := S;
    FSeatGot := True;
    if LobbyStatus <> nil then
      LobbyStatus.Text := 'Du sitzt als ' + RoleName[FMe] + '. Warte, bis der Gastgeber startet …';
  end
  else if P[0] = 'FULL' then
  begin
    LeaveNetwork;
    ShowJoinPage;
    LobbyStatus.Text := 'Der Tisch ist schon voll oder die App-Version passt nicht.';
  end
  else if (P[0] = 'START') and (Length(P) = 6) and not FInGame and FSeatGot then
  begin
    S := StrToIntDef(P[1], -1);
    if (S < 0) or (S > 3) then
      Exit;
    FNames[0] := Copy(P[2], 1, 20);
    FNames[1] := Copy(P[3], 1, 20);
    FNames[2] := Copy(P[4], 1, 20);
    FNames[3] := Copy(P[5], 1, 20);
    StartGame(S);
  end
  else if (P[0] = 'D') and (Length(P) = 4) and FInGame and (Length(P[1]) = 1) then
  begin
    S := StrToIntDef(P[2], -1);
    if (S >= 0) and (S <= 3) then
      Enqueue(P[1][1], S, P[3]);
  end;
end;

procedure TGameForm.StartGame(Dealer: TSeat);
var
  C: TCard;
begin
  LobbyOverlay.Visible := False;
  FInGame := True;
  Bummerl[0] := 0;
  Bummerl[1] := 0;
  for C := Low(TCard) to High(TCard) do
    Views[C].Visible := False;
  ApplySeatLook;
  NewBummerl(Dealer);
end;

procedure TGameForm.ConfirmMenu;
begin
  Pause(True);
  ShowOverlay('Zurück zum Menü?', 'Die laufende Partie wird beendet' +
    IfThen(FRole = nrSolo, '.', ' und die Verbindung getrennt.') + sLineBreak + sLineBreak +
    'Daneben klicken bricht ab.', 'Zum Menü', ShowLobby, True);
end;

{ Ablauf }

procedure TGameForm.NewBummerl(Dealer: TSeat);
begin
  Inc(FGen);
  FQueue.Clear;
  FInbox.Clear;
  FWait.Active := False;
  Overlay.Visible := False;
  Scores[0] := 0;
  Scores[1] := 0;
  FDealer := Dealer;
  UpdateScore;
  StartHand;
end;

procedure TGameForm.StartHand;
var
  S: TSeat;
begin
  HidePanel;
  FAwaitHuman := False;
  FCardDone := nil;
  FTrumpKnown := False;
  FPlaying := False;
  FResetScores := False;
  FTrick.Clear;
  for S := Low(TSeat) to High(TSeat) do
    VisHand[S] := [];
  SetActivePlate(-1);
  Decide('D', FDealer, 0,
    function: string
    begin
      Result := DeckToStr(ShuffledDeck);
    end,
    nil,
    procedure(V: string)
    var
      Deck: TArray<TCard>;
    begin
      ParseDeck(V, Deck);
      FSteps := DealCards(G, FDealer, Deck);
      LayDeck;
    end);
end;

procedure TGameForm.LayDeck;
var
  I: Integer;
  V: TCardView;
begin
  for I := 19 downto 0 do
  begin
    V := Views[FSteps[I].Card];
    V.StopPropertyAnimation('Opacity');
    V.StopPropertyAnimation('Position.X');
    V.StopPropertyAnimation('Position.Y');
    V.StopPropertyAnimation('RotationAngle');
    V.Visible := True;
    V.Opacity := 1;
    V.Dim := False;
    V.Playable := False;
    V.Cursor := crDefault;
    V.HitTest := False;
    V.TurnTo(False);
    V.Loc := clDeck;
    V.StackIndex := 19 - I;
    V.Jitter := Random * 4 - 2;
    V.BringToFront;
    PlaceCard(V);
  end;
  UpdateHud;
  UpdatePlates;
  Hint(SeatName(FDealer) + Verb(FDealer, ' gibst', ' gibt') + ' – ' + SeatName(G.Rufer) +
    Verb(G.Rufer, ' rufst', ' ruft') + ' Trumpf');
  After(500,
    procedure
    begin
      DealRange(0, 2, ChooseTrump);
    end);
end;

procedure TGameForm.DealRange(First, Last: Integer; const Done: TProc);
var
  I: Integer;
  V: TCardView;
  S: TSeat;
  Affected: set of TSeat;
  C: TCard;
  Delay: Single;
begin
  Affected := [];
  for I := First to Last do
  begin
    V := Views[FSteps[I].Card];
    V.Loc := clHand;
    V.Seat := FSteps[I].Seat;
    Include(VisHand[V.Seat], V.Card);
    Include(Affected, V.Seat);
  end;
  for S in Affected do
    for C in VisHand[S] do
      if Views[C].Loc = clHand then
        PlaceCard(Views[C], 0.3);
  for I := First to Last do
  begin
    V := Views[FSteps[I].Card];
    Delay := (I - First) * 0.085;
    V.BringToFront;
    PlaceCard(V, 0.42, Delay);
    if V.Seat = FMe then
      V.TurnTo(True, 0.3, Delay + 0.3);
  end;
  After(Round(((Last - First) * 0.085 + 0.7) * 1000),
    procedure
    var
      P: TSeat;
    begin
      for P := Low(TSeat) to High(TSeat) do
        RelayoutHand(P, 0.2);
      Done();
    end);
end;

procedure TGameForm.ChooseTrump;
var
  I: Integer;
  First3: TCards;
begin
  First3 := [];
  for I := 0 to 2 do
    Include(First3, FSteps[I].Card);
  // drei Buben: neu geben
  if (RankOf(FSteps[0].Card) = rkBube) and (RankOf(FSteps[1].Card) = rkBube) and (RankOf(FSteps[2].Card) = rkBube) then
  begin
    Say(G.Rufer, 'Drei Buben – neu geben!');
    After(1800, StartHand);
    Exit;
  end;
  SetActivePlate(G.Rufer);
  if G.Rufer = FMe then
    Hint('Du bist Rufer – wähle die Trumpffarbe')
  else
    Hint(SeatName(G.Rufer) + ' ruft Trumpf …');
  Decide('T', G.Rufer, 900,
    function: string
    begin
      Result := IntToStr(Ord(AIChooseTrump(First3)));
    end,
    procedure(Done: TProc<string>)
    begin
      Ask('Trumpf rufen',
        [SuitSymbol[suKreuz] + ' Kreuz', SuitSymbol[suPik] + ' Pik', SuitSymbol[suHerz] + ' Herz',
         SuitSymbol[suKaro] + ' Karo', 'Blind'],
        ['', '', '', '', '4. Karte entscheidet'],
        procedure(I: Integer)
        begin
          Done(IntToStr(I));
        end);
    end,
    procedure(V: string)
    var
      K, Choice: Integer;
    begin
      Choice := StrToInt(V);
      if Choice < 4 then
        SetTrump(TSuit(Choice))
      else
        for K := 3 to 19 do
          if FSteps[K].Seat = G.Rufer then
          begin
            SetTrump(SuitOf(FSteps[K].Card));
            Exit;
          end;
    end);
end;

procedure TGameForm.SetTrump(T: TSuit);
begin
  G.Trump := T;
  FTrumpKnown := True;
  Say(G.Rufer, SuitSymbol[T] + ' ' + SuitName[T] + '!');
  UpdateHud;
  RelayoutHand(FMe, 0.3);
  Hint('');
  After(800,
    procedure
    begin
      DealRange(3, 19, StartBidding);
    end);
end;

procedure TGameForm.StartBidding;
begin
  FBid := ctNormal;
  FBidDecl := G.Rufer;
  FBidSeat := G.Rufer;
  FBidPasses := 0;
  UpdateHud;
  NextBid;
end;

procedure TGameForm.NextBid;
var
  Allowed: TContracts;
begin
  if FBidPasses >= 4 - Ord(FBid <> ctNormal) then
  begin
    EndBidding;
    Exit;
  end;
  Allowed := AllowedBids(G, FBidSeat, FBid, FBidDecl);
  if Allowed = [] then
  begin
    BidResult(FBidSeat, ctNormal, False);
    Exit;
  end;
  SetActivePlate(FBidSeat);
  Decide('B', FBidSeat, 700,
    function: string
    begin
      Result := IntToStr(Ord(AIChooseBid(G, FBidSeat, FBid, FBidDecl)));
    end,
    procedure(Done: TProc<string>)
    var
      C: TContract;
      Opts: TArray<TContract>;
      Caps, Subs: TArray<string>;
    begin
      Opts := [];
      Caps := [];
      Subs := [];
      for C in Allowed do
      begin
        Opts := Opts + [C];
        Caps := Caps + [ContractName[C]];
        Subs := Subs + [Plural(ContractValue[C])];
      end;
      Caps := Caps + ['Weiter'];
      Subs := Subs + [IfThen(FBid = ctNormal, 'normales Spiel', 'nichts Höheres')];
      if FBid = ctNormal then
        Hint('Willst du ein Spiel ansagen? Details unter „Regeln“')
      else
        Hint(SeatName(FBidDecl) + Verb(FBidDecl, ' hast ', ' hat ') + ContractName[FBid] + ' angesagt – überbieten?');
      Ask('Ansagen', Caps, Subs,
        procedure(I: Integer)
        begin
          Hint('');
          if I < Length(Opts) then
            Done(IntToStr(Ord(Opts[I])))
          else
            Done('0');
        end);
    end,
    procedure(V: string)
    begin
      BidResult(FBidSeat, TContract(StrToInt(V)), True);
    end);
end;

procedure TGameForm.BidResult(Seat: TSeat; C: TContract; Speak: Boolean);
begin
  if C <> ctNormal then
  begin
    FBid := C;
    FBidDecl := Seat;
    FBidPasses := 0;
    Say(Seat, ContractName[C] + '!');
  end
  else
  begin
    Inc(FBidPasses);
    if Speak then
      Say(Seat, 'Weiter');
  end;
  FBidSeat := NextSeat(FBidSeat);
  After(IfThen(Speak, 600, 0), NextBid);
end;

procedure TGameForm.EndBidding;
var
  C: TCard;
begin
  FMult := 1;
  if GoalOf(FBid) = glInstant then
  begin
    StartPlay(G, FBid, FBidDecl, 1);
    FPlaying := True;
    UpdateHud;
    UpdatePlates;
    for C in VisHand[FBidDecl] do
      Views[C].TurnTo(True, 0.35);
    After(1500, ShowResult);
    Exit;
  end;
  SpritzenStep(0);
end;

procedure TGameForm.SpritzenStep(Idx: Integer);
var
  D: TSeat;
begin
  if Idx > 1 then
  begin
    BeginPlay;
    Exit;
  end;
  D := (FBidDecl + 1 + Idx * 2) mod 4;
  Decide('S', D, 450,
    function: string
    begin
      Result := IfThen(AIWantsSpritzen(G, D, FBid, FBidDecl), '1', '0');
    end,
    procedure(Done: TProc<string>)
    begin
      Ask('Spritzen?', ['Spritzen', 'Nein'],
        [IfThen(FBid = ctNormal, 'gegen ' + SeatName(FBidDecl) + ' · ×2', ContractName[FBid] + ' · ×2'), 'weiterspielen'],
        procedure(I: Integer)
        begin
          Done(IfThen(I = 0, '1', '0'));
        end);
    end,
    procedure(V: string)
    begin
      if V = '1' then
        Spritzt(D)
      else
        SpritzenStep(Idx + 1);
    end);
end;

procedure TGameForm.Spritzt(D: TSeat);
begin
  FMult := 2;
  Say(D, 'Gspritzt!');
  Decide('R', FBidDecl, 900,
    function: string
    begin
      Result := IfThen(AIWantsRetour(G, FBidDecl, FBid, FBidDecl), '1', '0');
    end,
    procedure(Done: TProc<string>)
    begin
      After(700,
        procedure
        begin
          Ask('Zurückspritzen?', ['Retour', 'Nein'], ['×4', 'bei ×2 bleiben'],
            procedure(I: Integer)
            begin
              Done(IfThen(I = 0, '1', '0'));
            end);
        end);
    end,
    procedure(V: string)
    begin
      if V = '1' then
      begin
        FMult := 4;
        Say(FBidDecl, 'Retour!');
      end;
      After(600, BeginPlay);
    end);
end;

procedure TGameForm.BeginPlay;
var
  C: TCard;
  S: TSeat;
begin
  StartPlay(G, FBid, FBidDecl, FMult);
  FPlaying := True;
  UpdateHud;
  UpdatePlates;
  for S := Low(TSeat) to High(TSeat) do
  begin
    for C in VisHand[S] do
      if not G.Active[S] then
        TAnimator.AnimateFloat(Views[C], 'Opacity', 0.35, 0.4);
    RelayoutHand(S, 0.3);
  end;
  if G.OpenHand and (G.Declarer <> FMe) then
    for C in VisHand[G.Declarer] do
      Views[C].TurnTo(True, 0.35);
  if G.Contract = ctNormal then
    Hint('Normales Spiel – ' + SeatName(G.Rufer) + Verb(G.Rufer, ' spielst', ' spielt') + ' aus')
  else
    Hint(SeatName(G.Declarer) + Verb(G.Declarer, ' spielst ', ' spielt ') + ContractName[G.Contract]);
  After(1300, NextTurn);
end;

procedure TGameForm.NextTurn;
var
  P: TSeat;
begin
  if G.Finished then
  begin
    EndHand;
    Exit;
  end;
  P := G.Turn;
  SetActivePlate(P);
  if P <> FMe then
    Hint('');
  Decide('C', P, 600,
    function: string
    begin
      Result := IntToStr(AIChooseCard(G));
    end,
    procedure(Done: TProc<string>)
    var
      L: TCards;
      C: TCard;
    begin
      L := LegalMoves(G);
      for C in VisHand[FMe] do
      begin
        Views[C].Playable := C in L;
        Views[C].Dim := not (C in L);
        Views[C].HitTest := True;
        Views[C].Cursor := IfThen(C in L, crHandPoint, crDefault);
        Views[C].Repaint;
      end;
      FCardDone := Done;
      FAwaitHuman := True;
      if G.TrickCount = 0 then
        Hint('Du spielst aus – klick auf eine Karte')
      else if CardCount(L) < CardCount(VisHand[FMe]) then
        Hint('Du bist dran – Farb- und Stichzwang: nur helle Karten erlaubt')
      else
        Hint('Du bist dran');
    end,
    procedure(V: string)
    begin
      DoPlay(StrToInt(V));
    end);
end;

procedure TGameForm.CardClicked(V: TCardView);
var
  C: TCard;
  Done: TProc<string>;
begin
  if not FAwaitHuman or not V.Playable then
    Exit;
  FAwaitHuman := False;
  for C in VisHand[FMe] do
  begin
    Views[C].Playable := False;
    Views[C].Dim := False;
    Views[C].HitTest := False;
    Views[C].Cursor := crDefault;
    Views[C].Repaint;
  end;
  Hint('');
  Done := FCardDone;
  FCardDone := nil;
  Done(IntToStr(V.Card));
end;

procedure TGameForm.DoPlay(C: TCard);
var
  P: TSeat;
  V: TCardView;
  Done: Boolean;
begin
  P := G.Turn;
  Done := PlayCard(G, C);
  V := Views[C];
  Exclude(VisHand[P], C);
  V.Loc := clTrick;
  V.Seat := P;
  V.Jitter := Random * 18 - 9;
  V.JX := Random * 12 - 6;
  V.JY := Random * 12 - 6;
  V.Playable := False;
  V.Dim := False;
  V.StopPropertyAnimation('Opacity');
  V.Opacity := 1;
  V.BringToFront;
  PlaceCard(V, 0.4);
  if not V.FaceUp then
    V.TurnTo(True, 0.32, 0.04);
  RelayoutHand(P, 0.3);
  FTrick.Add(V);
  if G.LastMeld > 0 then
    Say(P, IfThen(G.LastMeld = 40, 'Vierziger!', 'Zwanziger!'));
  UpdatePlates;
  if Done then
    After(1150,
      procedure
      begin
        CollectTrick(G.LastTrickWinner);
      end)
  else if G.Finished then
    After(1200, EndHand)
  else
    After(450, NextTurn);
end;

procedure TGameForm.CollectTrick(W: TSeat);
var
  V: TCardView;
  P: TPointF;
  I: Integer;
begin
  P := PlateCenter(W);
  I := 0;
  for V in FTrick do
  begin
    V.Loc := clGone;
    MoveView(V, P.X, P.Y, V.RotationAngle + 20 - I * 8, 0.45, I * 0.03);
    TAnimator.AnimateFloatDelay(V, 'Opacity', 0, 0.3, 0.2 + I * 0.03);
    Inc(I);
  end;
  FTrick.Clear;
  After(500, NextTurn);
end;

procedure TGameForm.EndHand;
var
  S: TSeat;
  C: TCard;
  K: Integer;
begin
  Hint('');
  SetActivePlate(-1);
  K := 0;
  for S := Low(TSeat) to High(TSeat) do
    for C in VisHand[S] do
      if not Views[C].FaceUp then
      begin
        Views[C].TurnTo(True, 0.35, K * 0.05);
        Inc(K);
      end;
  After(900 + K * 50, ShowResult);
end;

procedure TGameForm.ShowResult;
var
  T, L, My: Integer;
  Title, Detail, Who, Opp: string;
  Schneider: Boolean;
begin
  T := G.WinnerTeam;
  L := 1 - T;
  My := MyTeam;
  Opp := FNames[(FMe + 1) mod 4] + ' & ' + FNames[(FMe + 3) mod 4];
  if T = My then
    Title := 'Gewonnen!'
  else
    Title := 'Verloren';
  if G.Contract = ctNormal then
  begin
    if T = My then
      Who := 'Ihr'
    else
      Who := Opp;
    if (G.TricksDone = 5) and (G.TeamPoints[T] + G.TeamMelds[T] < 66) then
      Detail := Who + IfThen(T = My, ' habt', ' haben') + ' den letzten Stich gemacht.'
    else
      Detail := Format('%s %s 66 erreicht (%d : %d Augen inkl. 20/40).',
        [Who, IfThen(T = My, 'habt', 'haben'), G.TeamPoints[T] + G.TeamMelds[T], G.TeamPoints[L] + G.TeamMelds[L]]);
  end
  else
  begin
    Who := SeatName(G.Declarer);
    if T = TeamOf(G.Declarer) then
      Detail := Who + Verb(G.Declarer, ' hast den ', ' hat den ') + ContractName[G.Contract] + ' gewonnen.'
    else
      Detail := Who + Verb(G.Declarer, ' bist mit dem ', ' ist mit dem ') + ContractName[G.Contract] + ' gescheitert.';
  end;
  if G.Multiplier > 1 then
    Detail := Detail + ' Gespritzt ×' + IntToStr(G.Multiplier) + '.';
  Detail := Detail + sLineBreak + sLineBreak + IfThen(T = My, 'Wir bekommen ', 'Die Gegner bekommen ') + Plural(G.Points) + '.';
  Inc(Scores[T], G.Points);
  UpdateScore;
  if Scores[T] >= 24 then
  begin
    Schneider := Scores[L] = 0;
    Inc(Bummerl[T], 1 + Ord(Schneider));
    Title := IfThen(T = My, 'Bummerl gewonnen!', 'Bummerl verloren');
    Detail := Detail + sLineBreak + IfThen(T = My, 'Ihr gewinnt das Bummerl', Opp + ' gewinnen das Bummerl') +
      Format(' %d : %d', [Scores[My], Scores[1 - My]]) + IfThen(Schneider, ' – mit Schneider!', '!');
    FResetScores := True;
    UpdateScore;
  end;
  if FLogFile <> '' then
    TFile.AppendAllText(FLogFile, Format('%s %s team%d +%d  %d:%d  bummerl %d:%d%s',
      [ContractName[G.Contract], FNames[G.Declarer], T, G.Points, Scores[0], Scores[1],
       Bummerl[0], Bummerl[1], sLineBreak]));
  ShowOverlay(Title, Detail, IfThen(FResetScores, 'Neues Bummerl', 'Nächstes Spiel'),
    procedure
    var
      C: TCard;
    begin
      if FResetScores then
      begin
        Scores[0] := 0;
        Scores[1] := 0;
        UpdateScore;
      end;
      for C := Low(TCard) to High(TCard) do
        Views[C].Visible := False;
      FDealer := NextSeat(FDealer);
      StartHand;
    end);
  if FAuto then
    After(1500,
      procedure
      begin
        if Overlay.Visible then
          ResultButton.Action();
      end);
end;

initialization

finalization
  FreeCardCache;

end.
