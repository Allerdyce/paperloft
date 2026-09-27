#!/bin/bash
# Extraction never reads labels. Only the frozen scorer receives ground truth.
set -euo pipefail
cd "$(dirname "$0")/.."
model=system
mode=fixtures
input=Tests/Fixtures
while [ "$#" -gt 0 ]; do
  case "$1" in
    --model) model="${2:?missing model}"; shift 2 ;;
    --holdout) mode=holdout; input="${2:?missing directory}"; shift 2 ;;
    --private) mode=private; input="$HOME/Factory/private-samples"; shift ;;
    *) echo "Usage: scripts/eval.sh [--model stub|parser|system] [--holdout DIR|--private]" >&2; exit 2 ;;
  esac
done
case "$model" in stub|parser|system) ;; *) echo 'Unknown backend' >&2; exit 2 ;; esac
if [ "$mode" = private ] && [ ! -f "$input/labels.jsonl" ]; then
  echo 'Private samples: not scored; independently supplied labels are unavailable.'
  exit 0
fi
[ -f "$input/labels.jsonl" ] || { echo 'Evaluation labels missing' >&2; exit 2; }
mkdir -p build evidence
evaluation_commit="$(git rev-parse HEAD)"
if [ -n "$(git status --porcelain -- Packages scripts Tests/Fixtures)" ]; then
  evaluation_commit="$evaluation_commit-dirty"
fi
swift build --package-path Packages/PaperloftKit -c release --product PaperloftEval > build/eval-build.log 2>&1
bin="$(swift build --package-path Packages/PaperloftKit -c release --show-bin-path)"
temporary="$(mktemp -d "$PWD/build/eval-XXXXXX")"
cleanup() {
  python3 - "$temporary" <<'PY'
import pathlib, shutil, sys
path = pathlib.Path(sys.argv[1])
assert path.parent == pathlib.Path.cwd() / 'build' and path.name.startswith('eval-')
shutil.rmtree(path)
PY
}
trap cleanup EXIT
"$bin/PaperloftEval" "$model" "$input" "$temporary/predictions.jsonl"
score_mode="$mode"
[ "$mode" != fixtures ] || [ "$model" != parser ] || score_mode=parser
args=(--labels "$input/labels.jsonl" --predictions "$temporary/predictions.jsonl" --mode "$score_mode")
if [ "$mode" = fixtures ]; then
  cp "$temporary/predictions.jsonl" "evidence/predictions-$model.jsonl"
  args+=(--history evidence/eval-history.csv --commit "$evaluation_commit")
fi
python3 scripts/score_eval.py "${args[@]}"
