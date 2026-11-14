# Jakulo The Lost City – Ideen für die Weiterentwicklung

Nov 12, 2026 · @Paul Meyer

## Ausgangslage

Level 1 steht als Dschungelpfad mit Tempeltor und Portal am Ende. Jedes weitere Level führt eine neue Mechanik ein und bringt den Spieler näher an die „Lost City“.

## Vorschlag: Levelfolge

### Level 1 – Prolog/Tutorial

- Spieler befindet sich auf einem Dschungelpfad
- Muss Hindernissen wie Baumstämmen, Gruben mit Lianen und Krokodilen ausweichen. Die Hindernisse kommen einzeln und zuerst harmlos: erst ein Stamm, dann eine Grube mit Liane, dann ein langsames Krokodil
- Am Ende des Levels findet man in einer alten Ruine ein altes Buch (das man aufschlagen und interagieren kann)
  - dort erfährt man über die Lost City und kann die Missionsziele sehen
  - Man kann dort die Karte mit den einzelnen Leveln, Notizen (etwa über Ureinwohner, Tiere sehen) und die Erfolge, Münzen, Items etc sehen

### Level 2 – Dschungel mit feindlichen Ureinwohner

- Spieler wird durch ein Portal hierhin teleportiert

* Die **Krokodile aus Level 1** kehren schwieriger zurück: mehrere hintereinander und schnelleres Maul-Timing.
* Spieler muss sich durch Dorf von Ureinwohnern schleichen ohne dass sie ihn bemerken
* Am Ende erhält der Spieler als Item eine Trinkflasche mit der er Leben auffüllen kann

### Level 3 – Fluss & Sumpf

- Neues Item: **Schlinge**. Damit trifft man entfernte Ziele und vertreibt Tiere.
- Treibholz, das sich bewegt, und Seerosen, die unter dem Spieler absinken.
- Ein Wasserfall als Abschluss von Akt 1.

### Level 4 – Unterirdische Höhlen / Tunnel

- Pitfall hatte die Unterwelt unter dem Dschungel. Fällt man durch eine Grube, landet man unten statt zu sterben.
- Neue Mechanik: **Dunkelheit + Fackel** als begrenztes Lichtfeld (OmniLight3D am Spieler, Fackeln an Wänden anzünden).
- Gegner: Skorpione und Spinnen, die von der Decke kommen, dazu Tiere, die auf den Spieler zulaufen und denen er ausweichen muss.

### Level 5 – Verlassene Mine

- Neues Item: **Dynamit**. Damit sprengt man verschüttete Wege frei.
- Entscheidung: einen verschütteten Rivalen retten oder die Ladung für eine Abkürzung nutzen.

### Level 6 – Bergpass / Gletscher

- Neues Item: **Eispickel**. Damit klettert man Eiswände hoch.
- Abschluss von Akt 2, Blick auf die Lost City.

### Level 7 – Tempelruinen (Eingang der Lost City)

- Neue Mechanik: **Rätsel mit Hebel und Seilwinde**. Ein Hebel öffnet ein Tor, die Winde hebt eine Plattform.
- Rollende Stämme bzw. Steinkugeln auf der Tempeltreppe (Indiana-Jones-Moment).
- Stachelfallen mit Timing, Druckplatten im Boden.

### Level 8 – Die verlorene Stadt

- Größeres, offeneres Areal statt eines Pfads. Dafür passt die Third-Person-Kamera gut.
- Alle Items werden kombiniert gebraucht.

### Level 9 – Finale

- Bossgegner: **Jaguar** mit Angriffsmustern (Ansprung, Rückzug) oder eine Wächterstatue, die erwacht.
- Letzte Entscheidung über das Artefakt, danach eines von drei Enden.

## Systeme, die sich durch alle Level ziehen

- **Levelwechsel über das Portal.** Am Ende von Level 1 steht es schon; nötig sind nur ein Area3D und `get_tree().change_scene_to_file()`. Kommt zusammen mit dem Grundgerüst von Level 2.
- **Game-State-Autoload** mit Leben, Münzen und Punkten über die Level hinweg. `max_health = 3` sitzt aktuell nur im Player.
- **Checkpoints** innerhalb längerer Level (Modell `checkpoint.glb` ist vorhanden).
- **Sammelobjekte mit Sinn:** z. B. 3 versteckte Juwelen pro Level, die am Ende den Bosskampf erleichtern oder ein Bonuslevel freischalten.
- **Optional, passend zum Original:** ein Timer pro Level für Highscore-Jagd.

## Akte und Items

Die neun Level verteilen sich auf drei Akte, und jedes Level ab Level 2 bringt eine neue Mechanik oder ein Item.

| Akt | Level | Neue Mechanik / Item |
| --- | --- | --- |
| 1 – Dschungel | 1 Prolog | Buch |
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

## Entscheidungen und Enden

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

## Nächste Schritte

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

## Ideen-Parkplatz

Ideen, die feststehen, aber erst später umgesetzt werden.

- **Helfer-Charakter (Level 2):** Der Spieler lernt in Level 2 einen Charakter kennen, der ihm hilft. Man begegnet ihm später im Spiel noch einmal. Er ist der gefangene Dorfbewohner aus der Entscheidung in Level 2: Ob der Spieler ihn befreit, bestimmt, ob er später wieder hilft.
- **Überflutung (Level 3):** Das Level wird mit der Zeit überflutet, der Wasserspiegel steigt.
- **Als Tier spielen (Level 4 bis 6):** Einmal schlüpft der Spieler in die Rolle eines Tiers, um ein Level zu lösen, z. B. als Skorpion (passt zu den Höhlen in Level 4) oder als Pinguin (passt zum Gletscher in Level 6).
