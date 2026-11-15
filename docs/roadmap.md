# **Jakulo The Lost City – Ideen für die Weiterentwicklung**

Nov 12, 2026 · @Paul Meyer

## **Ausgangslage**

Level 1 steht als Dschungelpfad mit Tempeltor und Portal am Ende. Jedes weitere Level führt eine neue Mechanik ein und bringt den Spieler näher an die „Lost City“.

## **Vorschlag: Levelfolge**

### **Level 1 – Tutorial**

- Spieler befindet sich auf einem Dschungelpfad
- Muss Hindernissen wie Baumstämmen, Gruben mit Lianen und Krokodilen ausweichen. Die Hindernisse kommen einzeln und zuerst harmlos: erst ein Stamm, dann eine Grube mit Liane, dann ein langsames Krokodil
- Am Ende des Levels findet man in einer alten Ruine ein altes Buch (das man aufschlagen und interagieren kann)
  - dort erfährt man über die Lost City und kann die Missionsziele sehen
  - Man kann dort die Karte mit den einzelnen Leveln, Notizen (etwa über Ureinwohner, Tiere sehen) und die Erfolge, Münzen, Items etc sehen

### **Level 2 – Dschungel mit feindlichen Ureinwohner**

- Spieler wird durch ein Portal hierhin teleportiert

* Die **Krokodile aus Level 1** kehren schwieriger zurück: mehrere hintereinander und schnelleres Maul-Timing.
* Spieler muss sich durch Dorf von Ureinwohnern schleichen ohne dass sie ihn bemerken
* Am Ende erhält der Spieler als Item eine Trinkflasche mit der er Leben auffüllen kann

### **Level 3 – Fluss & Sumpf**

- Neues Item: **Schlinge**. Damit trifft man entfernte Ziele und vertreibt Tiere.
- Treibholz, das sich bewegt, und Seerosen, die unter dem Spieler absinken.
- Ein Wasserfall als Abschluss von Akt 1.

### **Level 4 – Unterirdische Höhlen / Tunnel**

- Pitfall hatte die Unterwelt unter dem Dschungel. Fällt man durch eine Grube, landet man unten statt zu sterben.
- Neue Mechanik: **Dunkelheit + Fackel** als begrenztes Lichtfeld (OmniLight3D am Spieler, Fackeln an Wänden anzünden).
- Gegner: Skorpione und Spinnen, die von der Decke kommen, dazu Tiere, die auf den Spieler zulaufen und denen er ausweichen muss.

### **Level 5 – Verlassene Mine**

- Neues Item: **Dynamit**. Damit sprengt man verschüttete Wege frei.
- Entscheidung: einen verschütteten Rivalen retten oder die Ladung für eine Abkürzung nutzen.

### **Level 6 – Bergpass / Gletscher**

- Neues Item: **Eispickel**. Damit klettert man Eiswände hoch.
- Abschluss von Akt 2, Blick auf die Lost City.

### **Level 7 – Tempelruinen (Eingang der Lost City)**

- Neue Mechanik: **Rätsel mit Hebel und Seilwinde**. Ein Hebel öffnet ein Tor, die Winde hebt eine Plattform.
- Rollende Stämme bzw. Steinkugeln auf der Tempeltreppe (Indiana-Jones-Moment).
- Stachelfallen mit Timing, Druckplatten im Boden.

### **Level 8 – Die verlorene Stadt**

- Größeres, offeneres Areal statt eines Pfads. Dafür passt die Third-Person-Kamera gut.
- Alle Items werden kombiniert gebraucht.

### **Level 9 – Finale**

- Bossgegner: **Jaguar** mit Angriffsmustern (Ansprung, Rückzug) oder eine Wächterstatue, die erwacht.
- Letzte Entscheidung über das Artefakt, danach eines von drei Enden.

## **Systeme, die sich durch alle Level ziehen**

- **Levelwechsel über das Portal.** Am Ende von Level 1 steht es schon; nötig sind nur ein Area3D und `get_tree().change_scene_to_file()`. Kommt zusammen mit dem Grundgerüst von Level 2.
- **Game-State-Autoload** mit Leben, Münzen und Punkten über die Level hinweg. `max_health = 3` sitzt aktuell nur im Player.
- **Checkpoints** innerhalb längerer Level (Modell `checkpoint.glb` ist vorhanden).
- **Sammelobjekte mit Sinn:** z. B. 3 versteckte Juwelen pro Level, die am Ende den Bosskampf erleichtern oder ein Bonuslevel freischalten.
- **Optional, passend zum Original:** ein Timer pro Level für Highscore-Jagd.

## **Akte und Items**

Die neun Level verteilen sich auf drei Akte, und jedes Level ab Level 2 bringt eine neue Mechanik oder ein Item.

| **Akt** | **Level** | **Neue Mechanik / Item** |
| --- | --- | --- |
| 1 – Dschungel | 1 Tutorial | Buch |
| 1 – Dschungel | 2 Dorf | Schleichen, Trinkflasche |
| 1 – Dschungel | 3 Fluss & Sumpf | Schlinge |
| 2 – Unterwelt & Berge | 4 Höhlen | Fackel, Dunkelheit |
| 2 – Unterwelt & Berge | 5 Verlassene Mine | Dynamit |
| 2 – Unterwelt & Berge | 6 Bergpass / Gletscher | Eispickel |
| 3 – Lost City | 7 Tempelruinen | Hebel- und Windenrätsel |
| 3 – Lost City | 8 Die Stadt | alle Items kombiniert |
| 3 – Lost City | 9 Finale | Boss und Enden |

- **Geheimwege:** Items öffnen Wege in früheren Leveln, z. B. eine Eiswand in Level 4 oder einen sprengbaren Fels in Level 2. Dort liegen die versteckten Juwelen.
- **Technik:** ein Inventar im Game State und eine `Item`-Resource pro Gegenstand. Sprengbare Felsen und Eiswände sind eigene Szenen, die auf das passende Item reagieren.

## **Entscheidungen und Enden**

Vier Schlüsselentscheidungen verändern bestehende Level und führen zu drei Enden.

1. **Level 2:** Einem gefangenen Dorfbewohner helfen oder vorbeischleichen. Wer hilft, bekommt später einen Verbündeten und einen Hinweis im Buch. Der Dorfbewohner ist der Helfer-Charakter aus dem Ideen-Parkplatz.
2. **Level 5:** Den verschütteten Rivalen mit dem Dynamit retten oder die Ladung für eine Abkürzung nutzen.
3. **Level 7:** Den Tempelschatz mitnehmen (mehr Münzen, aber die Wächter erwachen) oder liegen lassen.
4. **Level 9:** Das Artefakt mitnehmen, zurücklassen oder den Wächtern übergeben.

Die Enden:

- **Schatzjäger:** Der Spieler nimmt alles mit, die Stadt stürzt ein.
- **Hüter:** Das Artefakt bleibt zurück, die Stadt bleibt verborgen.
- **Geheimes Ende:** nur mit allen Notizen und geholfenen Figuren.

Technik: ein `decisions`-Dictionary im Game State plus ein Zähler (z. B. „Vertrauen“). Level fragen die Werte beim Laden ab und schalten Knoten ein oder aus. Die Dialog-UI ist ein CanvasLayer mit Text und zwei Buttons nach dem Vorbild der Buch-UI.

## **Nächste Schritte**

Akt 1 (Level 1 bis 3) wird komplett spielbar, bevor Akt 2 beginnt. Neu dazu kommen das Item-System mit der Schlinge als erstem Item und das Entscheidungs-System mit der einen Entscheidung in Level 2 als Test. Danach folgen die Level 4 bis 9 nacheinander, pro Level ein Item.

1. **Notizen-System:** Einträge werden freigeschaltet, wenn man etwas zum ersten Mal trifft (z. B. Krokodil, später Ureinwohner und Tiere).
2. **Krokodile wiederverwendbar machen:** Maul-Intervall und Zeitversatz als `@export` setzen, damit sie in Level 2 schneller und versetzt hintereinander laufen können.
3. **Level 2 Grundgerüst:** Szene anlegen, das Portal aus Level 1 hierher führen lassen, Dschungelpfad mit der Krokodil-Kette.
4. **Schleich-Mechanik im Dorf:**
   - Sichtkegel der Ureinwohner (Area3D plus RayCast3D für die Sichtlinie)
   - Entdeckungsanzeige, die langsam steigt
   - Ducken bzw. Schleichen beim Spieler
   - Folge bei Entdeckung festlegen (zurück zum Checkpoint?)
5. **Trinkflasche als Belohnung:** Item im Game State speichern, mit einer Taste trinken, das füllt Leben auf. Optional mit begrenzten Ladungen.
6. **Angreifende Tiere (Level 4):** einfacher Gegner, der auf den Spieler zuläuft und dem man ausweichen muss.

## **Prolog – Schiffbruch**

Der Prolog ist eine überspringbare Zwischensequenz von 45 bis 60 Sekunden ohne Sprachausgabe: Der Held erleidet auf der Suche nach El Dorado Schiffbruch und wacht allein im Dschungel auf.

### **Ablauf in fünf Einstellungen**

1. **Ruhige See (ca. 10 s):** Das Schiff fährt bei Abendlicht. Texteinblendung, z. B. „Auf der Suche nach El Dorado“. Der Held steht an Deck und studiert eine Karte.
2. **Der Sturm zieht auf (ca. 10 s):** Der Himmel wird dunkel, Regen setzt ein, das Schiff beginnt zu schwanken. Die Kamera wackelt leicht mit.
3. **Das Unglück (ca. 15 s):** Hohe Wellen, Blitze, ein Mast bricht oder das Schiff läuft auf ein Riff. Der Held wird über Bord gespült, die Karte fliegt davon.
4. **Schwarzblende (ca. 5 s):** Nur noch Geräusche: Wellen, dann Stille, dann Dschungelvögel.
5. **Erwachen (ca. 10 s):** Der Held liegt am Ufer zwischen Wrackteilen und steht auf. Die Kamera fährt in die Third-Person-Sicht, der Spieler übernimmt, Level 1 beginnt.

### **Verbindung zum restlichen Spiel**

- **Das Buch:** Die Karte geht im Sturm verloren. Das alte Buch in der Ruine am Ende von Level 1 ersetzt sie.
- **Wrackteile am Start von Level 1:** Kisten, Fässer und Treibholz (`crate.glb`, `barrel.glb`, `driftwood.glb`) sind vorhanden.
- **El Dorado und Lost City:** Vorschlag: Die Lost City ist El Dorado. Das Buch deutet das am Ende von Level 1 an.

### **Umsetzung in Godot**

- **Eigene Szene `prolog.tscn`** als Startszene, die am Ende per `change_scene_to_file()` zu Level 1 wechselt.
- **Ein AnimationPlayer** steuert Kamerafahrten, Schiffsbewegung, Lichtfarbe, Texteinblendungen und die Schwarzblende (ColorRect im CanvasLayer).
- **Sturm:** Regen als GPUParticles3D, Blitze als kurze Lichtimpulse, Wellen über ein schwankendes Schiff statt echter Wassersimulation.
- **Überspringen:** eine Taste wechselt direkt zu Level 1. Der Game State merkt sich, dass der Prolog gesehen wurde.
- **Fehlende Assets:** ein Low-Poly-Schiff, eine Meeresfläche, eine Aufsteh-Animation für den Helden, dazu Sturmgeräusche und Donner.

### **Reihenfolge**

1. Erst nur Einstellung 4 und 5 bauen (Schwarzblende, Erwachen am Ufer).
2. Danach die Schiffsszene mit Platzhalter-Boxen und fertigen Kamerafahrten.
3. Zum Schluss Schiff-Modell, Sturm und Sound.

### **Stand (Nov 15, 2026)**

- scenes/prolog.tscn ist die Startszene (52 s, alle fünf Einstellungen). Erzeugt von tools/cutscenes/build\_prolog.gd, Verhalten in scripts/prolog.gd.
- Neue Low-Poly-Modelle aus Meshy in `assets/prolog/`: Schiff, Wrack am Strand, Schatzkarte. Das Meer ist ein eigener Shader (assets/prolog/sea.gdshader).
- Sturm, Regen, Blitze und Geräusche (Brandung, Regen, Donner, Vögel) hängen an einem Wert `storm`. Die Geräusche sind prozedural erzeugt und sollten später durch echte Samples ersetzt werden.
- Das Aufstehen ist die rückwärts abgespielte Umfall-Animation `Knock_Down`. Eine echte Aufsteh-Animation fehlt noch.
- Level 1 beginnt jetzt am Strand (scenes/level\_1\_beach.tscn, erzeugt von tools/cutscenes/build\_level\_1\_beach.gd): Wrack, Treibgut, Palmen und Meer hinter dem alten Startpunkt. Die Rückwand des Pfads ist offen, unsichtbare Wände begrenzen den Strand.

## **Level 2 – Plan für das Dorf**

Das Dorf wird eine Fläche von etwa 36 × 48 m (9 × 12 Kacheln) zwischen z = −180 und dem Portal. Der bisherige Gang ist nur 12 m breit und zum Schleichen zu schmal, der Boden muss also verbreitert werden.

### **Draufsicht**

Ein Zeichen ist eine Kachel (4 m). Unten kommt der Spieler rein, oben steht das Portal.

```
		 x: -16  ...  0  ...  +16
```

`z -224    #  #  #  #  P  #  #  #  #`

`z -220    #  #  .  .  T  .  .  #  #`

`z -216    G  .  .  W  .  .  .  H  K`

`z -212    G  .  H  .  .  .  H  .  W`

`z -208    G  .  H  .  F  .  .  .  .`

`z -204    G  G  .  .  W  .  H  H  .`

`z -200    .  G  .  .  .  .  .  .  .`

`z -196    H  .  .  W  .  .  .  H  G`

`z -192    G  .  .  .  C  .  .  .  G`

`z -188    G  G  .  .  .  .  .  G  G`

`z -184    #  #  #  .  W  .  #  #  #`

`z -180    #  #  #  .  .  .  #  #  #`

H = Hütte, G = hohes Gras, W = Wache, F = Lagerfeuer, K = Käfig, C = Checkpoint, T = Trinkflasche, P = Portal, # = Dschungel

### **Aufbau**

- **Einstieg (z −184):** eine einzelne Wache mit dem Rücken zum Spieler. Hier lernt man das Schleichen ohne Risiko, direkt danach kommt der Checkpoint.
- **Linke Route:** durchgehend hohes Gras am Rand. Sicher, aber langsam.
- **Mitte:** der kürzeste Weg, führt aber am Lagerfeuer und zwei Wachen vorbei.
- **Rechte Route:** hinter den Hütten entlang zum Käfig mit dem gefangenen Dorfbewohner. Dort steht eine eigene Wache, die Befreiung ist also ein bewusster Umweg.
- **Wachen:** fünf Stück. Die am Feuer und am Käfig stehen fest, die bei z −196 und z −216 patrouillieren quer, die am Einstieg ist die Übungswache.
- **Ziel:** Die Trinkflasche liegt auf einem Podest direkt vor dem Portal.

### **Assets**

- **Vorhanden:** `campfire.glb`, `tent.glb` (als Hütten-Ersatz), `crate.glb`, `barrel.glb`, `torch.glb`, `ruin_pedestal` und `grass_field.gd` fürs hohe Gras.
- **Fehlt noch:** ein Hütten-Modell, ein Käfig, die Wachen-Figur und die Schleich-Mechanik (Sichtkegel, Entdeckungsanzeige, Ducken).

## Level 3 – Plan für Fluss & Sumpf

Level 3 dreht sich um steigendes Wasser und Tempo, als Gegenstück zum Schleichen in Level 2. Das neue Item ist die Schlinge.

### Grundidee: Das Wasser steigt

- Der Spieler kommt in einem Flusstal an, kurz darauf setzt Regen ein und der Wasserspiegel steigt langsam.
- Der Weg führt stetig nach oben: vom Ufer über Felsen und Wurzeln bis in die Baumkronen.
- Das Wasser tötet nicht sofort. Wer hineinfällt, verliert ein Leben und landet am letzten Checkpoint, der noch trocken ist.

### Drei Abschnitte

1. **Flussufer (ruhig):** Hier findet man die Schlinge und lernt sie ohne Zeitdruck, z. B. an einer Frucht am Baum oder einem Wespennest, das einen Affen vertreibt.
2. **Der Sumpf (das Wasser beginnt zu steigen):** Treibholz und sinkende Seerosen als Trittsteine. Frühe Wege liegen später unter Wasser, dafür trägt das Wasser Treibholz nach oben und macht neue Wege erreichbar.
3. **Aufstieg zum Wasserfall (Finale):** Klettern über Lianen und Äste, während das Wasser dicht folgt. Oben am Wasserfall endet Akt 1.

### Einsatz der Schlinge

- **Schalter aus der Ferne:** ein Seil durchschießen, damit eine Brücke oder ein Baumstamm herunterfällt.
- **Tiere vertreiben:** Papageien oder Affen, die auf einem Ast den Weg blockieren (`parrot.glb` und `monkey.glb` sind vorhanden).
- **Krokodile betäuben:** Ein Treffer hält das Maul kurz geschlossen.

### Weitere Ideen

- **Versteckte Juwelen unter Zeitdruck:** Sie liegen in tiefen Bereichen, die früh überflutet werden.
- **Wiedersehen mit dem Dorfbewohner:** Hat man ihn in Level 2 befreit, wirft er an einer schwierigen Stelle eine Liane herunter.
- **Notizen fürs Buch:** Einträge zu Papagei, Affe und zur Regenzeit.

### Technik

- Das steigende Wasser ist eine Wasserfläche, deren Höhe ein Tween oder AnimationPlayer anhebt, mit einer Kill-Zone darunter. Der Meeres-Shader aus dem Prolog lässt sich wiederverwenden.
- Das Tempo hängt an Abschnitten statt an einer festen Uhr: Das Wasser steigt bis zu einer Marke und wartet dort, bis der Spieler den nächsten Checkpoint erreicht.

## **Ideen-Parkplatz**

Ideen, die feststehen, aber erst später umgesetzt werden.

- **Helfer-Charakter (Level 2):** Der Spieler lernt in Level 2 einen Charakter kennen, der ihm hilft. Man begegnet ihm später im Spiel noch einmal. Er ist der gefangene Dorfbewohner aus der Entscheidung in Level 2: Ob der Spieler ihn befreit, bestimmt, ob er später wieder hilft.
- **Überflutung (Level 3):** Das Level wird mit der Zeit überflutet, der Wasserspiegel steigt.
- **Als Tier spielen (Level 4 bis 6):** Einmal schlüpft der Spieler in die Rolle eines Tiers, um ein Level zu lösen, z. B. als Skorpion (passt zu den Höhlen in Level 4) oder als Pinguin (passt zum Gletscher in Level 6).
