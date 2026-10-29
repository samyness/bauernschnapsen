unit Schnapsen.Engine;

{ Regel-Engine für Bauernschnapsen (4 Spieler, 2 Teams, 20 Karten, Farb- und Stichzwang).
  Sitzplätze im Uhrzeigersinn: 0 = Du (unten), 1 = links, 2 = Partner (oben), 3 = rechts.
  Team 0 = Sitz 0+2, Team 1 = Sitz 1+3. }

interface

type
  TSuit = (suKreuz, suPik, suHerz, suKaro);
  TSuits = set of TSuit;
  TRank = (rkBube, rkDame, rkKoenig, rkZehn, rkAss);
  TCard = 0..19;
  TCards = set of TCard;
  TSeat = 0..3;

  TContract = (ctNormal, ctBettler, ctAssenbettler, ctSchnapser, ctPlauderer,
    ctGang, ctZehnergang, ctBauernschnapser, ctKontraschnapser,
    ctFarbenringerl, ctKontrabauer, ctHerrenschnapser);
  TContracts = set of TContract;

  TGoal = (glNormal, glSchnapser, glAllTricks, glNoTricks, glInstant);

  TDealStep = record
    Seat: TSeat;
    Card: TCard;
  end;

  TGame = record
    Hands: array[TSeat] of TCards;
    Dealer, Rufer, Declarer: TSeat;
    Trump: TSuit;
    Contract: TContract;
    Multiplier: Integer;
    Active: array[TSeat] of Boolean;
    OpenHand: Boolean;                     // Plauderer: Karten des Ansagers liegen offen
    Turn, Leader: TSeat;
    TrickCards: array[0..3] of TCard;
    TrickSeats: array[0..3] of TSeat;
    TrickCount, TricksDone: Integer;
    TricksWon: array[TSeat] of Integer;
    TeamPoints, TeamMelds: array[0..1] of Integer;
    Played: TCards;
    Voids: array[TSeat] of TSuits;
    LastMeld: Integer;                     // 20/40, die mit der zuletzt gespielten Karte angesagt wurden
    LastTrickWinner: TSeat;
    Finished: Boolean;
    WinnerTeam, Points: Integer;
  end;

const
  AllCards: TCards = [0..19];
  ContractName: array[TContract] of string = ('Normales Spiel', 'Bettler',
    'Assenbettler', 'Schnapser', 'Plauderer', 'Gang', 'Zehnergang',
    'Bauernschnapser', 'Kontraschnapser', 'Farbenringerl',
    'Kontrabauernschnapser', 'Herrenschnapser');
  ContractValue: array[TContract] of Integer = (1, 4, 5, 6, 7, 9, 10, 12, 12, 18, 24, 24);
  ContractRule: array[TContract] of string = (
    'Trumpf gilt. Wer zuerst 66 Augen hat, gewinnt: 1 Punkt, 2 wenn Gegner unter 33, 3 wenn Gegner stichlos. Sonst gewinnt der letzte Stich 1 Punkt.',
    'Allein, Partner pausiert. Kein Trumpf, keinen einzigen Stich machen.',
    'Wie Bettler, aber das Ass ist die niedrigste Karte (Zehn höchste).',
    'Rufer oder sein Partner. Trumpf gilt. Mit höchstens 3 eigenen Stichen (plus 20/40) 66 Augen erreichen.',
    'Bettler mit offenen Karten: Alle sehen die Karten des Ansagers.',
    'Allein alle 5 Stiche machen. Kein Trumpf, auch der Partner darf nicht stechen.',
    'Wie Gang, aber das Ass ist die niedrigste Karte (Zehn höchste).',
    'Rufer oder sein Partner. Trumpf gilt. Allein alle 5 Stiche machen.',
    'Ein Gegner des Rufers spielt einen Schnapser mit dem gerufenen Trumpf. Der Rufer spielt aus.',
    'Jeder außer dem Rufer: 5 Karten einer Nicht-Trumpffarbe, sofort gewonnen.',
    'Ein Gegner des Rufers macht mit dem gerufenen Trumpf alle 5 Stiche. Der Rufer spielt aus.',
    'Der Rufer hält alle 5 Trümpfe: sofort gewonnen.');
  SuitName: array[TSuit] of string = ('Kreuz', 'Pik', 'Herz', 'Karo');
  SuitSymbol: array[TSuit] of string = (#$2663, #$2660, #$2665, #$2666);
  RankName: array[TRank] of string = ('Bube', 'Dame', 'König', 'Zehn', 'Ass');
  RankShort: array[TRank] of string = ('B', 'D', 'K', '10', 'A');
  RankPoints: array[TRank] of Integer = (2, 3, 4, 10, 11);

function SuitOf(C: TCard): TSuit; inline;
function RankOf(C: TCard): TRank; inline;
function MakeCard(S: TSuit; R: TRank): TCard; inline;
function CardPoints(C: TCard): Integer; inline;
function CardCount(const Cards: TCards): Integer;
function SuitCards(const Cards: TCards; S: TSuit): TCards;
function TeamOf(P: TSeat): Integer; inline;
function NextSeat(P: TSeat): TSeat; inline;
function PartnerOf(P: TSeat): TSeat; inline;
function CardName(C: TCard): string;

function GoalOf(C: TContract): TGoal;
function HasTrump(C: TContract): Boolean;
function HasMelds(C: TContract): Boolean;
function PartnerSits(C: TContract): Boolean;

function ShuffledDeck: TArray<TCard>;
function DealCards(var G: TGame; Dealer: TSeat; const Deck: TArray<TCard>): TArray<TDealStep>;
function AllowedBids(const G: TGame; P: TSeat; Current: TContract; CurrentBidder: TSeat): TContracts;
procedure StartPlay(var G: TGame; Contract: TContract; Declarer: TSeat; Multiplier: Integer);
function ActiveCount(const G: TGame): Integer;
function CardStrength(const G: TGame; C: TCard): Integer;
function Beats(const G: TGame; A, B: TCard): Boolean;
function TrickWinnerIndex(const G: TGame): Integer;
function LegalMoves(const G: TGame): TCards;
function MeldFor(const G: TGame; C: TCard): Integer;
function PlayCard(var G: TGame; C: TCard): Boolean;

implementation

function SuitOf(C: TCard): TSuit;
begin
  Result := TSuit(C div 5);
end;

function RankOf(C: TCard): TRank;
begin
  Result := TRank(C mod 5);
end;

function MakeCard(S: TSuit; R: TRank): TCard;
begin
  Result := Ord(S) * 5 + Ord(R);
end;

function CardPoints(C: TCard): Integer;
begin
  Result := RankPoints[RankOf(C)];
end;

function CardCount(const Cards: TCards): Integer;
var
  C: TCard;
begin
  Result := 0;
  for C in Cards do
    Inc(Result);
end;

function SuitCards(const Cards: TCards; S: TSuit): TCards;
var
  C: TCard;
begin
  Result := [];
  for C in Cards do
    if SuitOf(C) = S then
      Include(Result, C);
end;

function TeamOf(P: TSeat): Integer;
begin
  Result := P and 1;
end;

function NextSeat(P: TSeat): TSeat;
begin
  Result := (P + 1) mod 4;
end;

function PartnerOf(P: TSeat): TSeat;
begin
  Result := (P + 2) mod 4;
end;

function CardName(C: TCard): string;
begin
  Result := SuitName[SuitOf(C)] + ' ' + RankName[RankOf(C)];
end;

function GoalOf(C: TContract): TGoal;
begin
  case C of
    ctNormal: Result := glNormal;
    ctSchnapser, ctKontraschnapser: Result := glSchnapser;
    ctGang, ctZehnergang, ctBauernschnapser, ctKontrabauer: Result := glAllTricks;
    ctBettler, ctAssenbettler, ctPlauderer: Result := glNoTricks;
  else
    Result := glInstant;
  end;
end;

function HasTrump(C: TContract): Boolean;
begin
  Result := C in [ctNormal, ctSchnapser, ctBauernschnapser, ctKontraschnapser,
    ctKontrabauer, ctHerrenschnapser];
end;

function HasMelds(C: TContract): Boolean;
begin
  Result := C in [ctNormal, ctSchnapser, ctKontraschnapser];
end;

function PartnerSits(C: TContract): Boolean;
begin
  Result := C in [ctBettler, ctAssenbettler, ctPlauderer];
end;

function ShuffledDeck: TArray<TCard>;
var
  I, J: Integer;
  T: TCard;
begin
  SetLength(Result, 20);
  for I := 0 to 19 do
    Result[I] := I;
  for I := 19 downto 1 do
  begin
    J := Random(I + 1);
    T := Result[I]; Result[I] := Result[J]; Result[J] := T;
  end;
end;

function DealCards(var G: TGame; Dealer: TSeat; const Deck: TArray<TCard>): TArray<TDealStep>;
var
  N, K: Integer;
  P: TSeat;

  procedure Give(Seat: TSeat; Count: Integer);
  var
    X: Integer;
  begin
    for X := 1 to Count do
    begin
      Result[N].Seat := Seat;
      Result[N].Card := Deck[N];
      Include(G.Hands[Seat], Deck[N]);
      Inc(N);
    end;
  end;

begin
  Assert(Length(Deck) = 20);
  G := Default(TGame);
  G.Dealer := Dealer;
  G.Rufer := NextSeat(Dealer);
  G.Declarer := G.Rufer;
  G.Multiplier := 1;
  SetLength(Result, 20);
  N := 0;
  // Rufer bekommt 3 Karten und ruft Trumpf, dann 3 an die anderen, dann je 2.
  Give(G.Rufer, 3);
  P := G.Rufer;
  for K := 1 to 3 do
  begin
    P := NextSeat(P);
    Give(P, 3);
  end;
  P := G.Rufer;
  for K := 1 to 4 do
  begin
    Give(P, 2);
    P := NextSeat(P);
  end;
end;

function BidPriority(const G: TGame; P: TSeat): Integer;
begin
  Result := (P - G.Rufer + 4) mod 4; // Vorhand, Partner des Gebers, Partner von Vorhand, Geber
end;

function AllowedBids(const G: TGame; P: TSeat; Current: TContract; CurrentBidder: TSeat): TContracts;
var
  C: TContract;
  S: TSuit;
  Ok: Boolean;
begin
  Result := [];
  for C := Succ(ctNormal) to High(TContract) do
  begin
    // gleich hoch darf nur, wer Vorrang vor dem bisherigen Ansager hat
    if (ContractValue[C] < ContractValue[Current]) or ((ContractValue[C] = ContractValue[Current]) and
       ((Current = ctNormal) or (BidPriority(G, P) >= BidPriority(G, CurrentBidder)))) then
      Continue;
    case C of
      ctSchnapser, ctBauernschnapser:
        Ok := TeamOf(P) = TeamOf(G.Rufer);
      ctHerrenschnapser:
        Ok := (P = G.Rufer) and (CardCount(SuitCards(G.Hands[P], G.Trump)) = 5);
      ctKontraschnapser, ctKontrabauer:
        Ok := TeamOf(P) <> TeamOf(G.Rufer);
      ctFarbenringerl:
        begin
          Ok := False;
          if P <> G.Rufer then
            for S := Low(TSuit) to High(TSuit) do
            if (S <> G.Trump) and (CardCount(SuitCards(G.Hands[P], S)) = 5) then
              Ok := True;
        end;
    else
      Ok := True;
    end;
    if Ok then
      Include(Result, C);
  end;
end;

procedure Finish(var G: TGame; Team: Integer; ByLastTrick: Boolean = False);
var
  L, V: Integer;
begin
  G.Finished := True;
  G.WinnerTeam := Team;
  if G.Contract = ctNormal then
  begin
    L := 1 - Team;
    if ByLastTrick then
      V := 1
    else if G.TricksWon[L] + G.TricksWon[L + 2] = 0 then
      V := 3
    else if G.TeamPoints[L] + G.TeamMelds[L] < 33 then
      V := 2
    else
      V := 1;
  end
  else
    V := ContractValue[G.Contract];
  G.Points := V * G.Multiplier;
end;

procedure StartPlay(var G: TGame; Contract: TContract; Declarer: TSeat; Multiplier: Integer);
var
  P: TSeat;
begin
  G.Contract := Contract;
  G.Declarer := Declarer;
  G.Multiplier := Multiplier;
  G.OpenHand := Contract = ctPlauderer;
  for P := Low(TSeat) to High(TSeat) do
    G.Active[P] := not (PartnerSits(Contract) and (P = PartnerOf(Declarer)));
  if HasTrump(Contract) then
    G.Leader := G.Rufer // bei Trumpfspielen spielt immer die Vorhand aus
  else
    G.Leader := Declarer;
  G.Turn := G.Leader;
  if GoalOf(Contract) = glInstant then
    Finish(G, TeamOf(Declarer));
end;

function ActiveCount(const G: TGame): Integer;
var
  P: TSeat;
begin
  Result := 0;
  for P := Low(TSeat) to High(TSeat) do
    if G.Active[P] then
      Inc(Result);
end;

function CardStrength(const G: TGame; C: TCard): Integer;
begin
  if (G.Contract in [ctAssenbettler, ctZehnergang]) and (RankOf(C) = rkAss) then
    Result := -1
  else
    Result := Ord(RankOf(C));
end;

function Beats(const G: TGame; A, B: TCard): Boolean;
begin
  if HasTrump(G.Contract) then
  begin
    if (SuitOf(A) = G.Trump) and (SuitOf(B) <> G.Trump) then
      Exit(True);
    if (SuitOf(B) = G.Trump) and (SuitOf(A) <> G.Trump) then
      Exit(False);
  end;
  Result := (SuitOf(A) = SuitOf(B)) and (CardStrength(G, A) > CardStrength(G, B));
end;

function TrickWinnerIndex(const G: TGame): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to G.TrickCount - 1 do
    if Beats(G, G.TrickCards[I], G.TrickCards[Result]) then
      Result := I;
end;

function LegalMoves(const G: TGame): TCards;
var
  Hand, Follow, Better: TCards;
  W, C: TCard;
begin
  Hand := G.Hands[G.Turn];
  if G.TrickCount = 0 then
    Exit(Hand);
  W := G.TrickCards[TrickWinnerIndex(G)];
  // Farbzwang, sonst Trumpfzwang; jeweils mit Stichzwang gegen die aktuell höchste Karte
  Follow := SuitCards(Hand, SuitOf(G.TrickCards[0]));
  if (Follow = []) and HasTrump(G.Contract) then
    Follow := SuitCards(Hand, G.Trump);
  if Follow = [] then
    Exit(Hand);
  Better := [];
  for C in Follow do
    if Beats(G, C, W) then
      Include(Better, C);
  if Better <> [] then
    Result := Better
  else
    Result := Follow;
end;

function MeldFor(const G: TGame; C: TCard): Integer;
var
  Other: TCard;
begin
  Result := 0;
  if (G.TrickCount <> 0) or not HasMelds(G.Contract) then
    Exit;
  if (GoalOf(G.Contract) = glSchnapser) and (G.Turn <> G.Declarer) then
    Exit;
  case RankOf(C) of
    rkDame: Other := MakeCard(SuitOf(C), rkKoenig);
    rkKoenig: Other := MakeCard(SuitOf(C), rkDame);
  else
    Exit;
  end;
  if Other in G.Hands[G.Turn] then
    if SuitOf(C) = G.Trump then
      Result := 40
    else
      Result := 20;
end;

function TeamHasTrick(const G: TGame; Team: Integer): Boolean;
begin
  Result := G.TricksWon[Team] + G.TricksWon[Team + 2] > 0;
end;

procedure CheckMeldWin(var G: TGame; P: TSeat);
var
  T: Integer;
begin
  T := TeamOf(P);
  if not TeamHasTrick(G, T) or (G.TeamPoints[T] + G.TeamMelds[T] < 66) then
    Exit;
  case GoalOf(G.Contract) of
    glNormal: Finish(G, T);
    glSchnapser: if P = G.Declarer then Finish(G, T);
  end;
end;

procedure CheckAfterTrick(var G: TGame; Winner: TSeat);
var
  T, D: Integer;
begin
  T := TeamOf(Winner);
  D := TeamOf(G.Declarer);
  case GoalOf(G.Contract) of
    glNormal:
      if G.TeamPoints[T] + G.TeamMelds[T] >= 66 then
        Finish(G, T)
      else if G.TricksDone = 5 then
        Finish(G, T, True);
    glSchnapser:
      if Winner <> G.Declarer then
        Finish(G, 1 - D)
      else if G.TeamPoints[D] + G.TeamMelds[D] >= 66 then
        Finish(G, D)
      else if G.TricksDone = 3 then
        Finish(G, 1 - D);
    glAllTricks:
      if Winner <> G.Declarer then
        Finish(G, 1 - D)
      else if G.TricksDone = 5 then
        Finish(G, D);
    glNoTricks:
      if Winner = G.Declarer then
        Finish(G, 1 - D)
      else if G.TricksDone = 5 then
        Finish(G, D);
  end;
end;

function PlayCard(var G: TGame; C: TCard): Boolean;
var
  P, Winner: TSeat;
  I, Pts: Integer;
  Led: TSuit;
begin
  Assert(not G.Finished, 'Spiel ist schon zu Ende');
  Assert(C in LegalMoves(G), 'Ungültige Karte');
  Result := False;
  P := G.Turn;
  G.LastMeld := MeldFor(G, C);
  if G.LastMeld > 0 then
  begin
    Inc(G.TeamMelds[TeamOf(P)], G.LastMeld);
    CheckMeldWin(G, P);
  end;
  if G.TrickCount > 0 then
  begin
    Led := SuitOf(G.TrickCards[0]);
    if SuitOf(C) <> Led then
    begin
      Include(G.Voids[P], Led);
      if HasTrump(G.Contract) and (SuitOf(C) <> G.Trump) then
        Include(G.Voids[P], G.Trump);
    end;
  end;
  Exclude(G.Hands[P], C);
  Include(G.Played, C);
  G.TrickCards[G.TrickCount] := C;
  G.TrickSeats[G.TrickCount] := P;
  Inc(G.TrickCount);
  if G.Finished then
    Exit;
  if G.TrickCount < ActiveCount(G) then
  begin
    repeat
      P := NextSeat(P);
    until G.Active[P];
    G.Turn := P;
    Exit;
  end;
  Winner := G.TrickSeats[TrickWinnerIndex(G)];
  Pts := 0;
  for I := 0 to G.TrickCount - 1 do
    Inc(Pts, CardPoints(G.TrickCards[I]));
  Inc(G.TeamPoints[TeamOf(Winner)], Pts);
  Inc(G.TricksWon[Winner]);
  Inc(G.TricksDone);
  G.LastTrickWinner := Winner;
  G.TrickCount := 0;
  G.Leader := Winner;
  G.Turn := Winner;
  Result := True;
  CheckAfterTrick(G, Winner);
end;

end.
