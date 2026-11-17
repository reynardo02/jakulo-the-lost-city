# Level-Überarbeitung – 17. November 2026

## Spielgefühl und Wahrnehmung

- Normale Sprünge: 100 ms Kulanz nach einer Kante, 120 ms Eingabepuffer vor der Landung. Der bestehende zweite Tastendruck für den weiten Sprung bleibt erhalten.
- `player_foley.gd`: Schritte nach zurückgelegter Laufstrecke, Landegeräusche und Oberflächen Erde, Holz, Stein und Wasser. Explizite `footstep_surface`-Metadaten an einem Kollisionskörper oder dessen Eltern haben Vorrang vor der Namenszuordnung.
- Die Schrittimpulse speisen gleichzeitig die Wahrnehmung. Stillstehen ist lautlos, Schleichen deutlich leiser; Landungen und Geräuschzonen erreichen Affen und Wachen.
- Wachen untersuchen Geräusche, verfolgen bei Sichtkontakt und suchen am zuletzt gesehenen Ort. Gefangen wird der Spieler erst in Greifnähe mit freier Sicht. Hindernis- und Bodenprüfungen verhindern Durchlaufen von Hütten bzw. Weiterlaufen über Abgründe. Dies ist lokale Bewegung, keine Navigation um beliebig komplexe Hindernisse.
- Exportierte Wachenparameter: `search_duration`, `chase_speed`, `pursuit_radius`, `show_view_cone`. Sichtkegel bleiben standardmäßig als Spielhilfe sichtbar.

## Gestaltung

- Level 1: zusätzliche Randpflanzen, Felsen, Laub, Schilf, Ruinenfragmente; ausgetretene Pfadabschnitte und etwas weniger Umgebungslicht.
- Strand: Sand mit feuchter Uferzone, Fußspuren zum Dschungel und kleine Wrackbretter.
- Level 2: Pfade verbinden Zugänge und Arbeitsbereiche. Auf diesen Pfaden entfällt kurzes Gras; die separaten hohen Versteckgrasbereiche bleiben erhalten. Trockenständer, Vorratstöpfe und Holzstapel ergänzen die Hütten. Zwei Bewohner haben kurze Geh-/Warteabläufe.
- Level 3: Seilzug mit Umlenkrollen vom Kronenhebel zur Schleuse; Zuflussgeräusch und Sprühpartikel bei offener Schleuse; Nässemarke am Baum entsprechend dem höchsten erreichten Wasserstand.
- Der Kronenhebel schließt jetzt auch sichtbar das Tor und beendet den Zufluss.
- Der Kronenhebel startet sofort die Abschluss-Cutscene. Beim Schnitt nach unten wird der Spieler zum Baumfuß versetzt; auch beim Überspringen landet er am End-Checkpoint `l3_ende`. Die zusätzliche Abstiegs-Liane entfällt. Alte `l3_abstieg`-Checkpoints werden beim Laden zum Boden migriert.
- Die Sumpfwege und die Lichtung in Level 3 haben zusätzlichen kurzen Grasbewuchs (30 bzw. 22 Halme pro Quadratmeter). Sprungflächen, Wasser und Hinderniskollisionen bleiben unverändert.
- Seerosen neigen ihr sichtbares Modell beim Betreten leicht; Wasserringe markieren Betreten bzw. Platschen. Die bestehende Seerosenkollision bleibt stabil.
- Sparsame räumliche Vogelrufe ergänzen die vorhandene Musik und den Regen.

## Bearbeitung und Reproduktion

Die zusätzlichen statischen Details liegen in `scenes/dressing/` und lassen sich im Editor bearbeiten. `tools/build_level_polish.py` erzeugt diese vier Dressing-Szenen deterministisch neu und bindet sie bei Bedarf ein. Es ersetzt keine vollständigen Level. Achtung: manuelle Änderungen innerhalb der vier Dressing-Dateien würden bei erneuter Generierung überschrieben.

Level 1 hat einen gedrehten Root und einen dazwischenliegenden einfachen `Node` namens `Umgebung`. Deshalb hängt sein Dressing unter `Umgebung`, passend zu den vorhandenen Geometriekoordinaten.

Die neuen kurzen WAVs sind eigene prozedural erzeugte Effekte. `python tools/generate_foley.py` reproduziert sie ohne externe Pakete. Sie können später durch Aufnahmen ersetzt werden.

Nach der Klangkorrektur bestehen die Schritte aus gefilterten Kontakt- und Reibgeräuschen ohne tonale Sinusanteile. Je Untergrund gibt es drei Schritt- und drei separate Landevarianten; direkte Wiederholungen werden vermieden. Schritte sind auf -13 dB, Landungen auf -8 dB Grundpegel abgesenkt, Tonhöhenvariation auf ±3 % begrenzt. `--foley-only` regeneriert nur diese 24 Clips. Die Hörreichweiten der Gegner bleiben von der leiseren Abmischung unabhängig.

Der Waldpfad in Level 1 verwendet nach der visuellen Korrektur 0,55 m halbe Breite und 0,24 Deckkraft mit weich auslaufender, unterbrochener Färbung. 65 % des kurzen Grases bleiben dort in reduzierter Höhe erhalten. Die Dorfeinstellungen bleiben unverändert.

`grass_field.gd` bietet `worn_paths` (bis zu acht Vector4-Segmente mit Welt-x/z-Endpunkten) und `path_half_width`. Grasmaske und Bodenfärbung verwenden dieselben Pfade.

## Prüfung

```text
godot --headless --path . --script res://tools/test_level_polish.gd
godot --path . --windowed --resolution 1280x720 --script res://tools/preview_level_polish.gd
```

Der Integrationstest prüft Bodenkontakt, Stille im Stand, Coyote-Sprung, gepufferten Sprung, Wachenwahrnehmung, Verfolgung und Sichtverlust, Affengehör, Schleusenzustände, sofortigen Cutscene-Start, normalen und übersprungenen Abschluss, alte Checkpoints und den erneuten Levelstart.

Die Vorschau rendert sechs Ansichten in `screenshots/polish_*.png`. Für die Aufnahmen sind Spieltrigger per Kollisionsmaske deaktiviert. Das beeinflusst keine gespeicherten Levels.

Ergebnis: alle 25 Integrationsprüfungen bestanden, letzter Testprozess mit Exitcode 0. Sechs Ansichten wurden mit dem konfigurierten D3D12-Mobile-Renderer erzeugt und visuell kontrolliert. Beim Beenden meldet Godot gelegentlich noch eine nicht freigegebene Instanz der vorhandenen Hintergrundmusik (`Secrets of the Canopy.mp3`).

Bestehende Projektmeldungen: Mobile-Rendering unterstützt die in Level 1/2 gesetzten SSAO-/SSIL-/Volumennebeloptionen nicht. Außerdem besitzt eine vorhandene Münzinstanz in Level 1 eine nicht gleichmäßige Skalierung, die Jolt normalisiert. Renderer und Münzgeometrie wurden nicht umgestellt.

Die Überarbeitung enthält keine vollständige neue Geländetopologie und keinen Austausch aller vorhandenen Modelle. Schwierigkeitsbalance und Audiomischung sollten zusätzlich mit einem zusammenhängenden menschlichen Durchlauf beurteilt werden.


# Nachtrag – 17. November 2026 (Abend)

## Schritte

- `tools/generate_foley.py` erzeugt die 24 Schritt- und Landeclips neu (44,1 kHz): Fersen- und Ballenkontakt plus Oberflächentextur aus vielen winzigen Körnern. Waldboden knistert nach Laub und Zweigen, Stein hat Sandgriesel, Holz klingt hohl, Wasser schwappt mit einzelnen Tropfen.
- Leiser abgemischt (`player_foley.gd`): Schritte bei -20 dB, Landungen bei -15 dB, Wasser 3 dB und Holz 1 dB leiser. Pro Schritt schwanken Tonhöhe (±6 %) und Pegel (±1,5 dB). Die Hörweite der Gegner bleibt unabhängig davon.

## Affen

- Sie werfen Steine statt Früchte. Ablauf: erschrecken, zum Spieler drehen (bei großen Winkeln mit Tippelschritten), wütend drohen, bücken und Stein greifen (Ende der Wurfanimation), kurz zielen, werfen. Der Stein sitzt dabei am Knochen `RightHand`.
- Der Stein fliegt auf einer echten Wurfparabel auf die Stelle, an der der Spieler beim Loslassen war (Streuung `aim_error`). Er prallt ab, bleibt liegen oder platscht ins Wasser (Ring und Geräusch). Wer sich bewegt, weicht aus.
- Fairness: Ein Affe trifft höchstens einmal pro Aufwachen und bleibt danach 12 s ruhig. Nach jedem Treffer gilt für alle Affen 3 s Schonfrist, damit ein geweckter Nachbar nicht sofort nachlegt.
- Danach sieht sich der Affe um, dreht sich zurück und schläft langsam ein.
- Neue Klänge: `stone_whoosh`, `stone_hit(_2)`, `stone_splash` (`python tools/generate_foley.py --stones-only`).

## Sumpfinseln (Level 3)

- `scripts/swamp_island.gd` ersetzt die eckigen Bodenkacheln im Sumpf durch organische Inseln: unregelmäßig ausgebuchteter Rand, oben Gras, außen eine Böschung aus Erde und nassem Schlamm (`assets/terrain/swamp_bank.gdshader`). Mesh und Kollision entstehen beim Start und auch im Editor.
- Die begehbare Fläche deckt jeweils mindestens das alte Kachelrechteck ab. Ausbuchtungen sind je Seite begrenzt, und das flache Wasser zwischen D1 und D2 bleibt gleich breit. Sprünge werden also nie länger.
- Am Ufer stehen Schilf, Flusssteine, Wurzeln und Treibholz, nie auf den Wegseiten. Dazu kommen fünf kleine Schlammbänke ohne Kollision als Kulisse am Rand.
- `grass_field.gd` streut Halme auch auf diese Inseln.
- `build_level_3.gd` erzeugt jetzt auch LandscapeDetails, JungleAmbience und FloodDetails, damit ein Neubau sie nicht verliert.

## Licht je Level

- `python tools/set_level_lighting.py` setzt Himmel, Umgebung, Nebel und Sonne für Level 1 und 2. Level 3 setzt sein Licht im eigenen Generator.
- Level 1 mit Strand: früher Morgen. Tiefe, goldene Sonne (18°), lange Schatten, warmer Dunst.
- Level 2: Abenddämmerung. Flache orangefarbene Sonne (13°), bläuliche Schatten. Das Lagerfeuer und drei Fackeln leuchten und flackern (`scripts/flicker_light.gd`).
- Level 3: kühler, grünlich-grauer Regendunst, etwas dunkler und kontrastreicher als vorher.

## Prüfung

```text
godot --headless --path . --script res://tools/level3/test_swamp.gd
godot --headless --path . --script res://tools/test_level_polish.gd
```

`test_swamp.gd` prüft Boden unter allen alten Kachelflächen, das flache Wasser, Stand auf einer Insel, Gras, Aufheben und Werfen, Treffer, Ruhe nach dem Treffer, keinen Doppeltreffer, das Wiedereinschlafen und das Ausweichen. Ergebnis: beide Tests ohne Fehler. Die Vorschau hat jetzt zusätzlich `screenshots/polish_level_3_islands.png`.
