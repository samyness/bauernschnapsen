unit Schnapsen.AI;

{ Computergegner: Monte-Carlo über zufällige, mit dem Spielverlauf verträgliche Kartenverteilungen,
  die mit einer schnellen Heuristik (PolicyMove) zu Ende gespielt werden. }

interface

uses
  Schnapsen.Engine;

type
  TAILevel = (alLeicht, alMittel, alSchwer);

const
  AILevelName: array[TAILevel] of string = ('Leicht', 'Mittel', 'Schwer');

var
  AILevel: TAILevel = alMittel; // nur der Host rechnet KI-Züge

function AIChooseTrump(const First3: TCards): TSuit;
function AIChooseCard(const G: TGame): TCard;
function AIWinRate(const G: TGame; Viewer: TSeat; Contract: TContract; Declarer: TSeat;
  Samples: Integer = 60): Double;
function AIChooseBid(const G: TGame; P: TSeat; Current: TContract; CurrentBidder: TSeat): TContract;
function AIWantsSpritzen(const G: TGame; P: TSeat; Contract: TContract; Declarer: TSeat): Boolean;
function AIWantsRetour(const G: TGame; P: TSeat; Contract: TContract; Declarer: TSeat): Boolean;
function PolicyMove(const G: TGame): TCard;
procedure Playout(var G: TGame);
function Determinize(const G: TGame; Viewer: TSeat): TGame;

implementation

uses
  System.SysUtils;

const
  CardSamples: array[TAILevel] of Integer = (0, 15, 60);
  BidSamples: array[TAILevel] of Integer = (30, 50, 80);
  BidThreshold: array[TAILevel] of Double = (0.85, 0.75, 0.7);

function AIChooseTrump(const First3: TCards): TSuit;
var
  Score: array[TSuit] of Integer;
  C: TCard;
  S: TSuit;
begin
  FillChar(Score, SizeOf(Score), 0);
  for C in First3 do
    Inc(Score[SuitOf(C)], 3 + Ord(RankOf(C)));
  Result := suKreuz;
  for S := Low(TSuit) to High(TSuit) do
    if Score[S] > Score[Result] then
      Result := S;
end;

function Determinize(const G: TGame; Viewer: TSeat): TGame;
var
  Pool: array[0..19] of TCard;
  Need, Have: array[TSeat] of Integer;
  N, I, J: Integer;
  P: TSeat;
  T: TCard;
  W: TGame;
  Hidden: TCards;

  // Backtracking: die echte Verteilung erfüllt alle Fehlfarben, also gibt es immer eine Lösung.
  function Assign(K: Integer): Boolean;
  var
    Order: array[0..3] of TSeat;
    A, B: Integer;
    X: TSeat;
  begin
    if K = N then
      Exit(True);
    for A := 0 to 3 do
      Order[A] := A;
    for A := 3 downto 1 do
    begin
      B := Random(A + 1);
      X := Order[A]; Order[A] := Order[B]; Order[B] := X;
    end;
    for A := 0 to 3 do
    begin
      X := Order[A];
      if (Have[X] < Need[X]) and not (SuitOf(Pool[K]) in G.Voids[X]) then
      begin
        Include(W.Hands[X], Pool[K]);
        Inc(Have[X]);
        if Assign(K + 1) then
          Exit(True);
        Exclude(W.Hands[X], Pool[K]);
        Dec(Have[X]);
      end;
    end;
    Result := False;
  end;

begin
  // Nur die Menge der verdeckten Karten und die Handgrößen fließen ein, nie wer was hält.
  Hidden := [];
  for P := Low(TSeat) to High(TSeat) do
  begin
    Need[P] := 0;
    if (P = Viewer) or (G.OpenHand and (P = G.Declarer)) then
      Continue;
    Need[P] := CardCount(G.Hands[P]);
    Hidden := Hidden + G.Hands[P];
  end;
  N := 0;
  for T in Hidden do
  begin
    Pool[N] := T;
    Inc(N);
  end;
  for I := N - 1 downto 1 do
  begin
    J := Random(I + 1);
    T := Pool[I]; Pool[I] := Pool[J]; Pool[J] := T;
  end;
  W := G;
  for P := Low(TSeat) to High(TSeat) do
  begin
    Have[P] := 0;
    if Need[P] > 0 then
      W.Hands[P] := [];
  end;
  if not Assign(0) then
    raise Exception.Create('Keine gültige Kartenverteilung');
  Result := W;
end;

function WinnerIfPlayed(const G: TGame; C: TCard): TSeat;
var
  T: TGame;
begin
  T := G;
  T.TrickCards[T.TrickCount] := C;
  T.TrickSeats[T.TrickCount] := T.Turn;
  Inc(T.TrickCount);
  Result := T.TrickSeats[TrickWinnerIndex(T)];
end;

// Ist es aus Sicht von P gut, wenn W den Stich bekommt?
function WantsWinner(const G: TGame; P, W: TSeat): Boolean;
var
  D: TSeat;
begin
  D := G.Declarer;
  case GoalOf(G.Contract) of
    glNormal: Result := TeamOf(W) = TeamOf(P);
    glSchnapser, glAllTricks:
      if TeamOf(P) = TeamOf(D) then Result := W = D else Result := W <> D;
    glNoTricks:
      if P = D then Result := W <> D else Result := W = D;
  else
    Result := True;
  end;
end;

function Power(const G: TGame; C: TCard): Integer;
begin
  Result := CardStrength(G, C);
  if HasTrump(G.Contract) and (SuitOf(C) = G.Trump) then
    Inc(Result, 10);
end;

function LeadMove(const G: TGame; const L: TCards): TCard;
var
  C: TCard;
  P: TSeat;
  S, Best: Integer;
  WantHigh: Boolean;
begin
  P := G.Turn;
  case GoalOf(G.Contract) of
    glNoTricks: WantHigh := False;
    glSchnapser, glAllTricks: WantHigh := (P = G.Declarer) or (TeamOf(P) <> TeamOf(G.Declarer));
  else
    WantHigh := True;
  end;
  Result := 0;
  Best := Low(Integer);
  for C in L do
  begin
    if WantHigh then
    begin
      S := Power(G, C) * 10;
      if MeldFor(G, C) > 0 then
        Inc(S, 200);
      // im normalen Spiel lieber Farb-Asse als Trümpfe ziehen
      if (G.Contract = ctNormal) and (SuitOf(C) = G.Trump) then
        Dec(S, 60);
    end
    else
      S := -Power(G, C) * 10 - CardPoints(C);
    if S > Best then
    begin
      Best := S;
      Result := C;
    end;
  end;
end;

// Einfache Heuristik ohne Vorausschau, nur auf Basis des Stichs bisher.
function QuickMove(const G: TGame): TCard;
var
  L: TCards;
  C: TCard;
  P, W: TSeat;
  Last, Trumpf: Boolean;
  S, Best: Integer;
begin
  L := LegalMoves(G);
  if G.TrickCount = 0 then
    Exit(LeadMove(G, L));
  P := G.Turn;
  Last := G.TrickCount = ActiveCount(G) - 1;
  Result := 0;
  Best := Low(Integer);
  for C in L do
  begin
    W := WinnerIfPlayed(G, C);
    Trumpf := HasTrump(G.Contract) and (SuitOf(C) = G.Trump);
    if WantsWinner(G, P, W) then
    begin
      if W = P then
      begin
        if Last then
          S := 1000 - Power(G, C) * 10 - CardPoints(C)
        else
          S := 1000 + Power(G, C) * 10;
      end
      else if GoalOf(G.Contract) = glNormal then
        S := 800 + CardPoints(C) * 5 - Ord(Trumpf) * 60
      else
        S := 800 + Power(G, C);
    end
    else
      S := 500 - CardPoints(C) * 5 - Power(G, C) - Ord(Trumpf) * 30;
    if S > Best then
    begin
      Best := S;
      Result := C;
    end;
  end;
end;

// Spielt C und lässt die übrigen Spieler den Stich per QuickMove fertig spielen.
function TrickOutcome(const G: TGame; C: TCard; out Pts: Integer): TSeat;
var
  T: TGame;
  P: TSeat;
  I: Integer;

  procedure Put(Card: TCard);
  begin
    Exclude(T.Hands[T.Turn], Card);
    T.TrickCards[T.TrickCount] := Card;
    T.TrickSeats[T.TrickCount] := T.Turn;
    Inc(T.TrickCount);
  end;

begin
  T := G;
  Put(C);
  P := T.Turn;
  while T.TrickCount < ActiveCount(T) do
  begin
    repeat
      P := NextSeat(P);
    until T.Active[P];
    T.Turn := P;
    Put(QuickMove(T));
  end;
  Pts := 0;
  for I := 0 to T.TrickCount - 1 do
    Inc(Pts, CardPoints(T.TrickCards[I]));
  Result := T.TrickSeats[TrickWinnerIndex(T)];
end;

// Heuristik mit Vorausschau bis Stichende (in der jeweils angenommenen Kartenverteilung).
function PolicyMove(const G: TGame): TCard;
var
  L: TCards;
  C: TCard;
  P, W: TSeat;
  Good: Boolean;
  S, Best, Pts: Integer;
begin
  L := LegalMoves(G);
  if CardCount(L) = 1 then
    for C in L do
      Exit(C);
  P := G.Turn;
  Result := 0;
  Best := Low(Integer);
  for C in L do
  begin
    W := TrickOutcome(G, C, Pts);
    Good := WantsWinner(G, P, W);
    case GoalOf(G.Contract) of
      glNormal:
        begin
          if Good then
            S := 1000 + Pts * 3 - Power(G, C) * 2
          else
            S := -Pts * 3 - CardPoints(C) * 3 - Power(G, C) * 2;
          if G.TrickCount = 0 then
            Inc(S, MeldFor(G, C) * 3);
        end;
      glNoTricks:
        S := Ord(Good) * 1000 + Power(G, C);   // gefahrlos hohe Karten loswerden
    else
      S := Ord(Good) * 1000 - Power(G, C);     // mit möglichst kleiner Karte durchkommen
    end;
    if S > Best then
    begin
      Best := S;
      Result := C;
    end;
  end;
end;

procedure Playout(var G: TGame);
begin
  while not G.Finished do
    PlayCard(G, PolicyMove(G));
end;

function Evaluate(const G: TGame; Team: Integer): Double;
begin
  if G.WinnerTeam = Team then
    Result := G.Points
  else
    Result := -G.Points;
  Result := Result + (G.TeamPoints[Team] - G.TeamPoints[1 - Team]) / 500;
end;

function AIChooseCard(const G: TGame): TCard;
var
  L: TCards;
  C: TCard;
  Worlds: TArray<TGame>;
  S: TGame;
  I: Integer;
  Sum, Best: Double;
  Samples, K: Integer;
begin
  L := LegalMoves(G);
  if CardCount(L) = 1 then
    for C in L do
      Exit(C);
  if AILevel = alLeicht then
  begin
    // ohne Vorausrechnung, mit gelegentlichen Fehlgriffen
    if Random < 0.3 then
    begin
      K := Random(CardCount(L));
      for C in L do
      begin
        if K = 0 then
          Exit(C);
        Dec(K);
      end;
    end;
    Exit(PolicyMove(Determinize(G, G.Turn)));
  end;
  Samples := CardSamples[AILevel];
  SetLength(Worlds, Samples);
  for I := 0 to Samples - 1 do
    Worlds[I] := Determinize(G, G.Turn);
  Result := 0;
  Best := -1E9;
  for C in L do
  begin
    Sum := 0;
    for I := 0 to Samples - 1 do
    begin
      S := Worlds[I];
      PlayCard(S, C);
      Playout(S);
      Sum := Sum + Evaluate(S, TeamOf(G.Turn));
    end;
    if Sum > Best then
    begin
      Best := Sum;
      Result := C;
    end;
  end;
end;

function AIWinRate(const G: TGame; Viewer: TSeat; Contract: TContract; Declarer: TSeat;
  Samples: Integer): Double;
var
  S: TGame;
  I, Wins: Integer;
begin
  Wins := 0;
  for I := 1 to Samples do
  begin
    S := Determinize(G, Viewer);
    StartPlay(S, Contract, Declarer, 1);
    Playout(S);
    if S.WinnerTeam = TeamOf(Declarer) then
      Inc(Wins);
  end;
  Result := Wins / Samples;
end;

function AIChooseBid(const G: TGame; P: TSeat; Current: TContract; CurrentBidder: TSeat): TContract;
var
  Allowed: TContracts;
  C: TContract;
  R, EV, BestEV: Double;
begin
  Allowed := AllowedBids(G, P, Current, CurrentBidder);
  for C := High(TContract) downto Succ(ctNormal) do
    if (C in Allowed) and (GoalOf(C) = glInstant) then
      Exit(C);
  Result := ctNormal;
  BestEV := 0;
  for C in Allowed do
  begin
    R := AIWinRate(G, P, C, P, 80);
    EV := ContractValue[C] * (2 * R - 1);
    // shortcut: Simulation spielt mit offenen Karten, daher Plauderer (offen) nur bei fast sicherem Sieg
    if (R >= 0.7 + 0.2 * Ord(C = ctPlauderer)) and (EV > BestEV) then
    begin
      BestEV := EV;
      Result := C;
    end;
  end;
end;

function AIWantsSpritzen(const G: TGame; P: TSeat; Contract: TContract; Declarer: TSeat): Boolean;
begin
  Result := (AILevel <> alLeicht) and (AIWinRate(G, P, Contract, Declarer, BidSamples[AILevel]) < 0.25);
end;

function AIWantsRetour(const G: TGame; P: TSeat; Contract: TContract; Declarer: TSeat): Boolean;
begin
  Result := (AILevel <> alLeicht) and (AIWinRate(G, P, Contract, Declarer, BidSamples[AILevel]) > 0.8);
end;

end.
