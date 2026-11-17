#!/usr/bin/env bash
# Erzeugt ein Level-3-Modell mit Meshy: Referenzbild (text-to-image) -> image-to-3d mit
# Smart Topology (Meshy T2), texturiert -> GLB nach assets/level3/<name>_t2.glb.
# Aufruf aus dem Projektordner: tools/meshy/gen_l3_t2.sh NAME POLYCOUNT "PROMPT"
set -u
NAME="$1"; POLY="$2"; PROMPT="$3"
M="npm exec --yes --package=meshy-cli@0.4.0 -- meshy"
WS="assets"
ROOT="assets/meshy_output"
FLAGS="--output-schema v1 --format json --no-update-check"
LOG="tools/meshy/logs/$NAME.log"
mkdir -p tools/meshy/logs
json() { python -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1"; }
step() { echo "[$NAME] $*" | tee -a "$LOG"; }

step "Referenzbild anfordern"
OUT=$($M text-to-image create --ai-model nano-banana-pro --prompt "$PROMPT" --aspect-ratio 1:1 --async $FLAGS 2>>"$LOG")
IMG=$(echo "$OUT" | json "d['result']['submission']['task_id']") || { step "FEHLER Bild-Auftrag: $OUT"; exit 1; }
step "Bild-Task $IMG"
PROJ=$($M project init --root "$ROOT" --name "l3-t2-$NAME" --task-id "$IMG" --task-type text-to-image --workspace "$WS" $FLAGS 2>>"$LOG" | json "d['result']['project_dir']")
step "Projekt $PROJ"
W=$($M text-to-image wait "$IMG" --timeout 600 --project "$PROJ" --stage reference --workspace "$WS" $FLAGS 2>>"$LOG")
step "Bild fertig: $(echo "$W" | json "d['result'].get('task',{}).get('status') or d['ok']")"
$M download --task-json "$PROJ/task_$IMG.json" --kind image --output-dir "$PROJ/reference" --project "$PROJ" --stage reference --workspace "$WS" $FLAGS >>"$LOG" 2>&1

step "3D-Modell anfordern (Smart Topology, $POLY Dreiecke)"
OUT=$($M image-to-3d create --input-task-id "$IMG" --model-type smart-topology --target-polycount "$POLY" \
	--should-texture true --enable-pbr true --texture-resolution 2k --target-formats glb --async \
	--project "$PROJ" --stage model --workspace "$WS" $FLAGS 2>>"$LOG")
TASK=$(echo "$OUT" | json "d['result']['submission']['task_id']") || { step "FEHLER 3D-Auftrag: $OUT"; exit 1; }
step "3D-Task $TASK"
W=$($M image-to-3d wait "$TASK" --timeout 900 --project "$PROJ" --stage model --workspace "$WS" $FLAGS 2>>"$LOG")
step "3D fertig: ok=$(echo "$W" | json "d['ok']")"
$M download --task-json "$PROJ/task_$TASK.json" --model-format glb --output "assets/level3/${NAME}_t2.glb" --overwrite \
	--project "$PROJ" --stage delivered --workspace "$WS" $FLAGS >>"$LOG" 2>&1
$M download --task-json "$PROJ/task_$TASK.json" --asset thumbnail.primary --output "$PROJ/preview.png" \
	--project "$PROJ" --stage preview --workspace "$WS" $FLAGS >>"$LOG" 2>&1
CR=$(python -c "import json;d=json.load(open('$PROJ/task_$IMG.json',encoding='utf-8'));e=json.load(open('$PROJ/task_$TASK.json',encoding='utf-8'));g=lambda x:(x.get('result',x)).get('consumed_credits');print(g(d),g(e))")
step "FERTIG $PROJ  Credits(Bild,3D)=$CR"
