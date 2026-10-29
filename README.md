# Bauernschnapsen

Österreichisches Bauernschnapsen als Delphi-FireMonkey-App für Windows und Android: du und dein Partner gegen zwei Gegner, wahlweise gegen die KI oder mit Freunden über Bluetooth.

## Funktionen

- Alle gängigen Spiele: Normales Spiel, Bettler, Assenbettler, Schnapser, Plauderer, Gang, Zehnergang, Bauernschnapser, Kontraschnapser, Farbenringerl, Kontrabauernschnapser, Herrenschnapser
- Trumpf rufen (auch blind), Ansagen mit Vorrang, Spritzen und Retour, 20/40, Bummerl bis 24 mit Schneider
- Farb- und Stichzwang, erlaubte Karten werden hervorgehoben
- Optionaler Trainingsmodus: Die schwere KI empfiehlt Trumpf, Ansage, Spritzen/Retour und die nächste Karte, gespielt wird weiterhin selbst
- KI in drei Stärken (Leicht, Mittel, Schwer). Sie sieht nur ihre eigenen Karten, ein Test prüft das.
- Mehrspieler über Bluetooth: Jeder Platz ist einzeln auf KI oder Mensch einstellbar. Der Gastgeber mischt und rechnet die KI, alle Geräte spielen im Gleichschritt.
- Animierte, selbst gezeichnete Karten, Querformat, skaliert vom Handy bis zum PC

## Bauen

RAD Studio 12 (Delphi): `Bauernschnapsen.dproj` öffnen und für Windows 64 oder Android 64 bauen.
Für Android sind die Bluetooth-Berechtigungen (Bluetooth, Bluetooth Connect, Bluetooth Scan) bereits im Projekt gesetzt.
Das App-Symbol erzeugt `icons/make_icons.ps1`.

## Mehrspieler

1. Die Handys in den Android-Bluetooth-Einstellungen koppeln.
2. Gastgeber: Plätze auf „Mensch“ stellen und **Spiel starten** tippen.
3. Mitspieler: **Spiel beitreten** tippen und das Gerät des Gastgebers wählen.

## Tests

- `Tests/EngineTests.dpr`: Regeln, tausende simulierte Spiele und der Nachweis, dass die KI keine verdeckten Karten kennt
- `Tests/NetTests.dpr`: Verbindungsschicht (TCP und simulierte Funkverbindung mit Lebenszeichen)
- Mehrspieler lokal mit mehreren Instanzen: `Bauernschnapsen.exe -tcp -host -auto -log host.txt` sowie dreimal `Bauernschnapsen.exe -tcp -join -auto -log cN.txt`. Danach müssen alle Protokolle identisch sein.

## Aufbau

| Datei | Inhalt |
|---|---|
| `Schnapsen.Engine.pas` | Regeln, Stiche, Wertung |
| `Schnapsen.AI.pas` | KI (Monte-Carlo über plausible Kartenverteilungen) |
| `Schnapsen.Net.pas` | Bluetooth-/TCP-Verbindungen, Lebenszeichen |
| `Main.pas` | Oberfläche, Animationen, Lobby, Mehrspieler-Ablauf |
