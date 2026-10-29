program EngineTests;

{$APPTYPE CONSOLE}
{$ASSERTIONS ON}

uses
  System.SysUtils,
  Schnapsen.Engine in '..\Schnapsen.Engine.pas',
  Schnapsen.AI in '..\Schnapsen.AI.pas';

procedure Check(Cond: Boolean; const Msg: string);
begin
  if not Cond then
    raise Exception.Create('FEHLER: ' + Msg);
end;

function Fresh(Trump: TSuit; Contract: TContract; Declarer: TSeat): TGame;
begin
  Result := Default(TGame);
  Result.Dealer := 3;
  Result.Rufer := 0;
  Result.Trump := Trump;
  StartPlay(Result, Contract, Declarer, 1);
end;

procedure RuleTests;
var
  G: TGame;
  C: TCard;
begin
  // Stichzwang: Farbe bedienen und überstechen
  G := Fresh(suHerz, ctNormal, 0);
  G.Hands[0] := [MakeCard(suPik, rkKoenig)];
  G.Hands[1] := [MakeCard(suPik, rkBube), MakeCard(suPik, rkAss), MakeCard(suHerz, rkAss)];
  PlayCard(G, MakeCard(suPik, rkKoenig));
  Check(LegalMoves(G) = [MakeCard(suPik, rkAss)], 'Stichzwang in Farbe');

  // Trumpfzwang wenn Farbe fehlt
  G := Fresh(suHerz, ctNormal, 0);
  G.Hands[0] := [MakeCard(suPik, rkKoenig)];
  G.Hands[1] := [MakeCard(suKaro, rkAss), MakeCard(suHerz, rkBube)];
  PlayCard(G, MakeCard(suPik, rkKoenig));
  Check(LegalMoves(G) = [MakeCard(suHerz, rkBube)], 'Trumpfzwang');

  // Assenbettler: Ass ist niedrigste Karte, kein Trumpf
  G := Fresh(suHerz, ctAssenbettler, 0);
  G.Hands[0] := [MakeCard(suPik, rkAss)];
  G.Hands[1] := [MakeCard(suPik, rkBube), MakeCard(suHerz, rkAss)];
  PlayCard(G, MakeCard(suPik, rkAss));
  Check(LegalMoves(G) = [MakeCard(suPik, rkBube)], 'Assenbettler Rangfolge');
  Check(not G.Active[2], 'Partner pausiert im Bettler');

  // Training fragt immer die schwere KI, ohne die gewählte Gegnerstärke zu verändern.
  AILevel := alLeicht;
  C := AIChooseCardAtLevel(G, alSchwer);
  Check((C in LegalMoves(G)) and (AILevel = alLeicht), 'Trainingsempfehlung');

  // 40er nach eigenem Stich gewinnt sofort
  G := Fresh(suHerz, ctNormal, 0);
  G.TricksWon[0] := 1;
  G.TeamPoints[0] := 30;
  G.Hands[0] := [MakeCard(suHerz, rkKoenig), MakeCard(suHerz, rkDame)];
  PlayCard(G, MakeCard(suHerz, rkDame));
  Check(G.Finished and (G.WinnerTeam = 0) and (G.Points = 3), '40er gewinnt, Gegner stichlos = 3');

  // Gang verloren, sobald jemand anderer sticht
  G := Fresh(suHerz, ctGang, 1);
  G.Hands[1] := [MakeCard(suPik, rkKoenig)];
  G.Hands[2] := [MakeCard(suPik, rkAss)];
  G.Hands[3] := [MakeCard(suPik, rkBube)];
  G.Hands[0] := [MakeCard(suPik, rkDame)];
  PlayCard(G, MakeCard(suPik, rkKoenig));
  PlayCard(G, MakeCard(suPik, rkAss));
  PlayCard(G, MakeCard(suPik, rkBube));
  PlayCard(G, MakeCard(suPik, rkDame));
  Check(G.Finished and (G.WinnerTeam = 0) and (G.Points = 9), 'Gang verhindert');

  // Herrenschnapser nur mit allen 5 Trümpfen
  G := Default(TGame);
  G.Rufer := 0;
  G.Trump := suKaro;
  G.Hands[0] := [15..19];
  Check(ctHerrenschnapser in AllowedBids(G, 0, ctNormal, 0), 'Herrenschnapser erlaubt');
  Check(not (ctKontrabauer in AllowedBids(G, 2, ctNormal, 0)), 'Kontra nur für Gegner');
  Check(ctKontrabauer in AllowedBids(G, 1, ctNormal, 0), 'Kontra für Gegner');
  Check(ctSchnapser in AllowedBids(G, 2, ctNormal, 0), 'Partner des Rufers darf Schnapser');
  Check(AllowedBids(G, 1, ctGang, 0) * [ctBettler, ctGang] = [], 'nur höhere Ansagen');
  Check(ctGang in AllowedBids(G, 0, ctGang, 3), 'gleich hoch mit Vorrang');
  Check(not (ctFarbenringerl in AllowedBids(G, 0, ctNormal, 0)), 'Rufer kein Farbenringerl');
  G.Hands[1] := [0..4];
  Check(ctFarbenringerl in AllowedBids(G, 1, ctNormal, 0), 'Farbenringerl');

  // Schnapser des Partners: Rufer spielt aus
  G := Fresh(suHerz, ctSchnapser, 2);
  Check(G.Turn = 0, 'Vorhand spielt bei Schnapser aus');

  // Letzter Stich ohne 66 zählt 1 Punkt
  G := Fresh(suHerz, ctNormal, 0);
  G.TricksDone := 4;
  G.TricksWon[1] := 4;
  G.TeamPoints[1] := 40;
  G.Hands[0] := [MakeCard(suPik, rkBube)];
  G.Hands[1] := [MakeCard(suPik, rkDame)];
  G.Hands[2] := [MakeCard(suKaro, rkBube)];
  G.Hands[3] := [MakeCard(suKaro, rkDame)];
  PlayCard(G, MakeCard(suPik, rkBube));
  PlayCard(G, MakeCard(suPik, rkDame));
  PlayCard(G, MakeCard(suKaro, rkBube));
  PlayCard(G, MakeCard(suKaro, rkDame));
  Check(G.Finished and (G.WinnerTeam = 1) and (G.Points = 1), 'letzter Stich 1 Punkt');
end;

procedure Simulate(Games: Integer);
var
  G: TGame;
  I: Integer;
  P: TSeat;
  C, Bid: TContract;
  Counts: array[TContract] of Integer;
  Cards, Passes: Integer;
begin
  FillChar(Counts, SizeOf(Counts), 0);
  for I := 1 to Games do
  begin
    AILevel := TAILevel(I mod 3);
    DealCards(G, I mod 4, ShuffledDeck);
    for P := Low(TSeat) to High(TSeat) do
      Check(CardCount(G.Hands[P]) = 5, 'je 5 Karten');
    G.Trump := TSuit(Random(4));
    // Reizen wie im UI: reihum ab Vorhand, Ende nach 3 (ohne Gebot 4) Pässen in Folge
    C := ctNormal;
    G.Declarer := G.Rufer;
    P := G.Rufer;
    Passes := 0;
    while Passes < 4 - Ord(C <> ctNormal) do
    begin
      Bid := AIChooseBid(G, P, C, G.Declarer);
      if Bid <> ctNormal then
      begin
        C := Bid;
        G.Declarer := P;
        Passes := 0;
      end
      else
        Inc(Passes);
      P := NextSeat(P);
    end;
    Inc(Counts[C]);
    StartPlay(G, C, G.Declarer, 1);
    Cards := 0;
    while not G.Finished do
    begin
      if G.Turn = 0 then
        PlayCard(G, AIChooseCard(G))
      else
        PlayCard(G, PolicyMove(G));
      Inc(Cards);
      Check(Cards <= 20, 'Spiel endet');
    end;
    Check(G.Points > 0, 'Punkte vergeben');
    if (C = ctNormal) and (G.TricksDone = 5) then
      Check(G.TeamPoints[0] + G.TeamPoints[1] = 120, '120 Augen');
  end;
  for C := Low(TContract) to High(TContract) do
    if Counts[C] > 0 then
      Writeln(Format('  %-22s %d', [ContractName[C], Counts[C]]));
end;

// Die KI darf verdeckte Karten nicht kennen: tauscht man sie (gleich plausibel) neu aus,
// muss jede Entscheidung bei gleichem Zufallsstartwert identisch bleiben.
procedure NoPeekTests(Rounds: Integer);
var
  G, G2: TGame;
  I, K, Steps, Seed: Integer;
  P: TSeat;
  Lv: TAILevel;
begin
  for I := 1 to Rounds do
  begin
    Lv := TAILevel(I mod 3);
    AILevel := Lv;
    DealCards(G, I mod 4, ShuffledDeck);
    G.Trump := TSuit(Random(4));
    // Ansagen und Spritzen aus Sicht eines Spielers
    P := TSeat(Random(4));
    G2 := Determinize(G, P);
    Seed := Random(MaxInt);
    RandSeed := Seed;
    K := Ord(AIChooseBid(G, P, ctNormal, G.Rufer));
    RandSeed := Seed;
    Check(K = Ord(AIChooseBid(G2, P, ctNormal, G.Rufer)), 'Ansage hängt von verdeckten Karten ab');
    RandSeed := Seed;
    K := Ord(AIWantsSpritzen(G, P, ctGang, NextSeat(P)));
    RandSeed := Seed;
    Check(K = Ord(AIWantsSpritzen(G2, P, ctGang, NextSeat(P))), 'Spritzen hängt von verdeckten Karten ab');
    // Kartenwahl mitten im Spiel
    StartPlay(G, ctNormal, G.Rufer, 1);
    Steps := Random(16);
    for K := 1 to Steps do
      if not G.Finished then
        PlayCard(G, PolicyMove(G));
    if G.Finished then
      Continue;
    G2 := Determinize(G, G.Turn);
    Seed := Random(MaxInt);
    RandSeed := Seed;
    K := AIChooseCard(G);
    RandSeed := Seed;
    Check(K = AIChooseCard(G2), 'Kartenwahl hängt von verdeckten Karten ab (' + AILevelName[Lv] + ')');
  end;
end;

begin
  Randomize;
  try
    NoPeekTests(600);
    Writeln('Kein Spicken: OK');
    RuleTests;
    Writeln('Regeltests OK');
    Simulate(600);
    Writeln('Simulation OK');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
