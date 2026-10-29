program Bauernschnapsen;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Types,
  Schnapsen.Engine in 'Schnapsen.Engine.pas',
  Schnapsen.AI in 'Schnapsen.AI.pas',
  Schnapsen.Net in 'Schnapsen.Net.pas',
  Main in 'Main.pas' {GameForm};

begin
  Randomize;
  Application.Initialize;
  // Kartentisch nur quer: am Handy ist hochkant für vier Hände zu schmal
  Application.FormFactor.Orientations := [TFormOrientation.Landscape, TFormOrientation.InvertedLandscape];
  Application.CreateForm(TGameForm, GameForm);
  Application.Run;
end.
