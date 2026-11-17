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

### **Level 3 – Sumpf & der große Baum**

- Teil 1: Sumpf mit Hindernissen und schlafenden Affen, an denen man vorbeischleicht.
- Teil 2: Auf einer Lichtung wird der Bereich überflutet. Der Spieler klettert mit dem neuen Item **Schlinge** einen großen Baum hoch und stoppt oben die Flut per Hebel.
- Der Dorfbewohner aus Level 2 kehrt zurück und zeigt den Weg zum nächsten Level.

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
| 1 – Dschungel | 3 Sumpf & großer Baum | Schlinge |
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

## Level 3 – Plan für Sumpf und den großen Baum

Level 3 besteht aus zwei Teilen: einem Sumpf, den man vorsichtig durchquert, und einem großen Baum, den man hochklettert, während die Lichtung überflutet wird. Das neue Item ist die Schlinge.

### Teil 1 – Der Sumpf

- **Hindernisse:** sinkende Seerosen, treibendes Holz, Schlammlöcher mit Lianen darüber und einzelne Krokodile. Alles ist aus Level 1 und 2 bekannt, hier aber dichter kombiniert.
- **Schlafende Affen:** Sie liegen auf Ästen und Inseln am Weg. Der Spieler schleicht geduckt vorbei, wie im Dorf.
- **Was Affen weckt:** rennen, ins Wasser platschen oder auf einen knackenden Ast treten. Knackende Äste sind sichtbar markiert, damit es fair bleibt.
- **Folge beim Aufwecken:** Die Affen bewerfen den Spieler mit Früchten und stoßen ihn zurück. Das kostet ein Leben oder wirft ihn ins Wasser, führt aber nicht sofort zum Checkpoint.
- **Aufbau:** erst ein einzelner Affe abseits des Wegs, dann zwei mit einem knackenden Ast dazwischen, am Ende eine ganze Gruppe direkt am Pfad.
- **Checkpoint** am Rand der Lichtung.

### Die Lichtung – Zwischensequenz

1. Der Spieler betritt die Lichtung, in der Mitte steht der große Baum.
2. Die Kamera schwenkt zu einem Feind an einem Hebel am Rand der Lichtung (ca. 10 bis 15 s, überspringbar).
3. Er legt den Hebel um, eine Schleuse öffnet sich und Wasser strömt herein.
4. Die Kamera kehrt zum Spieler zurück. Am Fuß des Baums liegt die Schlinge, direkt auf dem Weg nach oben.

### Teil 2 – Der große Baum

Der Aufstieg hat drei Ebenen, das Wasser steigt hinter dem Spieler her.

1. **Wurzeln:** Die Schlinge aufheben und am ersten Ziel ausprobieren. Das Wasser steigt hier noch langsam, damit man die neue Mechanik in Ruhe lernt.
2. **Stamm:** Äste und Holzplattformen führen spiralförmig nach oben. Ziele für die Schlinge:
   - ein Seil durchschießen, damit eine Plattform oder Strickleiter herunterfällt
   - ein Wespennest treffen, das Affen von einem Ast vertreibt
   - eine Zielscheibe treffen, die einen Ast als Brücke umklappt
3. **Krone:** ein letzter Sprungabschnitt, dann der Hebel. Er stoppt die Überflutung, das Wasser zieht sich zurück.

- **Checkpoints** auf jeder Ebene. Wer ins Wasser fällt, verliert ein Leben und startet am letzten trockenen Checkpoint.
- **Faires Tempo:** Das Wasser steigt bis zu einer Marke unter dem nächsten Checkpoint und wartet dort, bis der Spieler ihn erreicht.
- **Versteckte Juwelen** liegen auf Seitenästen, die ein zusätzliches Ziel für die Schlinge brauchen.

### Abschluss

- Nach dem Hebel sinkt das Wasser. Am Fuß des Baums wartet der Dorfbewohner aus Level 2.
- Er zeigt dem Spieler einen Weg zum nächsten Level. Vorschlag: Das abfließende Wasser hat zwischen den Wurzeln einen Höhleneingang freigelegt, der zu den Höhlen von Level 4 führt.
- Notizen fürs Buch: Affe, Schlinge, der große Baum.

### Offene Fragen

- **Wer ist der Feind am Hebel?** Vorschlag: der Rivale der anderen Expedition, der in Level 5 wieder auftaucht. Alternative: eine Wache aus dem Dorf.
- **Was passiert, wenn der Spieler den Dorfbewohner in Level 2 nicht befreit hat?** Vorschlag: Er taucht trotzdem auf, weil er sich selbst befreien konnte, ist aber misstrauisch und hilft nur knapp. Mit Befreiung hilft er zusätzlich schon beim Aufstieg, z. B. mit einer heruntergeworfenen Liane.

### Technik

- **Wasser:** eine Wasserfläche, deren Höhe ein Tween anhebt und nach dem Hebel wieder senkt, mit einer Kill-Zone darunter. Der Meeres-Shader aus dem Prolog lässt sich wiederverwenden.
- **Affen:** das Schleich-System aus dem Dorf, aber mit Geräusch statt Sichtkegel (Area3D um den Affen, die auf Rennen und knackende Äste reagiert).
- **Schlinge:** Zielen mit einer Taste, Projektil als RigidBody3D oder RayCast3D, Ziele als eigene Szene mit einem Signal `hit`.
- **Zwischensequenz:** AnimationPlayer mit eigener Kamera, wie im Prolog.
- **Fehlende Assets:** der große Baum mit Plattformen, Hebel und Schleuse (`lever.glb` ist vorhanden), die Schlinge, eine Schlaf-Animation für den Affen.

### Stand (Nov 16, 2026)

- scenes/level_3.tscn ist neu nach diesem Plan gebaut und wird von tools/level3/build_level_3.gd erzeugt. Das alte Level 3 (Fluss mit Regen und Papagei) ist gelöscht.
- **Sumpf:** schlafende Affen (scripts/sleeping_monkey.gd) hören aufrechtes Laufen, knackende Äste und Platschen im flachen Wasser (scripts/noise_zone.gd). Wach werfen sie Früchte, ein Treffer kostet ein Leben (`GameState.hurt()`) und stößt zurück. Aufbau: ein Affe abseits, zwei mit Ast dazwischen, eine Bande mit zwei Ästen und flachem Wasser. Dazu Seerosen, Liane über dem Schlammloch, Krokodil und Treibholz.
- **Lichtung:** Die Flut-Cutscene zeigt eine Wache aus dem Dorf am Schleusenhebel (offene Frage entschieden: Wache statt Rivale, weil das Modell da ist). Der Ablauf hängt an scripts/level_3_flow.gd.
- **Schlinge:** Man zielt selbst: Taste (F, linke Maustaste, R2) halten = Zielmodus mit Fadenkreuz und leichtem Zoom, loslassen = Schuss. Ziele in Reichweite tragen einen goldenen Ring, unter dem Fadenkreuz wird er rot. Getroffen ist, was höchstens ca. 1 m neben dem Zielstrahl liegt (scripts/sling.gd).
- **Großer Baum:** genau drei Ziele für die Schlinge, alle gut sichtbar: der rote Knoten am Seil (Stamm fällt als Rampe), das Wespennest über den Affen und eine große Zielscheibe, die einen Ast als Brücke umklappt. Große Plattformen mit Lücken unter 1 m, keine fahrende Plattform, das Wasser steigt langsam. Checkpoints l3_wurzeln, l3_stamm, l3_krone; das Wasser wartet jeweils knapp darunter.
- **Juwelen:** zwei auf Seitenästen, über einen festen Ast erreichbar (Item `jewel`).
- **Wetter:** Im ganzen Level regnet es (scripts/rain.gd): Tropfen über der Kamera, grauer Himmel, prozedurales Regenrauschen und ab und zu ein Blitz mit Donner.
- **Abschluss:** Nach dem Hebel steht der Spieler unten beim Dorfbewohner, der Höhleneingang ist frei. Ein Portal führt weiter, solange es Level 4 noch nicht gibt, aber zurück zum Spielanfang.
- **Affen:** geriggt mit Meshy (Rigging + Animationen Schlafen, Idle, Werfen, Wut, Rennen; tools/level3/extract_monkey_anims.gd, scripts/monkey_animator.gd). Schlafende Affen hören jeden, der aufrecht in ihrer Nähe ist (Radius 6–8,5 m), stampfen beim Aufwachen auf und werfen mit Wurfbewegung; ein Treffer kostet höchstens ein Leben pro Aufwachen. Geduckt kommt man direkt an ihnen vorbei.
- **Fehlt noch:** die Rivalen-Figur, Geräusche für Affen und Wasser.

## **Ideen-Parkplatz**

Ideen, die feststehen, aber erst später umgesetzt werden.

- **Helfer-Charakter (Level 2):** Der Spieler lernt in Level 2 einen Charakter kennen, der ihm hilft. Man begegnet ihm später im Spiel noch einmal. Er ist der gefangene Dorfbewohner aus der Entscheidung in Level 2: Ob der Spieler ihn befreit, bestimmt, ob er später wieder hilft.
- **Überflutung (Level 3):** Das Level wird mit der Zeit überflutet, der Wasserspiegel steigt.
- **Als Tier spielen (Level 4 bis 6):** Einmal schlüpft der Spieler in die Rolle eines Tiers, um ein Level zu lösen, z. B. als Skorpion (passt zu den Höhlen in Level 4) oder als Pinguin (passt zum Gletscher in Level 6).
