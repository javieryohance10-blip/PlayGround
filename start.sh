#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
PORT="${PORT:-3000}"
OUTPUT_DIR="$PROJECT_DIR/dist"
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"

run_timed() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  /usr/bin/time -p "$@"
}

[[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT > 0 && PORT < 65536 )) || { echo "Invalid PORT: $PORT" >&2; exit 1; }

if [[ -f "$PROJECT_DIR/package.json" ]]; then
  if [[ -f "$PROJECT_DIR/package-lock.json" ]]; then
    run_timed npm ci --no-audit --no-fund
  elif [[ -f "$PROJECT_DIR/npm-shrinkwrap.json" ]]; then
    run_timed npm install --no-audit --no-fund
  else
    run_timed npm install --no-audit --no-fund
  fi
  if node -e 'const p=require(process.argv[1]); process.exit(p.scripts?.build ? 0 : 1)' "$PROJECT_DIR/package.json"; then
    run_timed npm run build
  fi
fi

run_timed mkdir -p "$OUTPUT_DIR" "$WEB_DIR"

if [[ -f "$PROJECT_DIR/package.json" ]]; then
  [[ -f "$OUTPUT_DIR/index.html" ]] || { echo "Build did not create $OUTPUT_DIR/index.html" >&2; exit 1; }
elif [[ -f "$PROJECT_DIR/index.html" ]]; then
  run_timed cp "$PROJECT_DIR/index.html" "$OUTPUT_DIR/index.html"
else
  # This repository has no application source yet. Generate a small static landing page
  # as the build artifact so the configured preview remains usable and capturable.
  run_timed python3 - "$OUTPUT_DIR/index.html" <<'PY'
from pathlib import Path
import sys

html = '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#10131c">
  <title>PlayGround</title>
  <style>
    :root { color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #10131c; color: #f5f7ff; }
    * { box-sizing: border-box; }
    body { min-height: 100vh; margin: 0; display: grid; place-items: center; padding: 28px; background: radial-gradient(ellipse at 50% 12%, #26345a 0, #171c2b 38%, #10131c 75%); }
    main { width: min(100%, 760px); padding: clamp(30px, 7vw, 68px); border: 1px solid #ffffff20; border-radius: 28px; background: #181e2bd9; box-shadow: 0 28px 90px #0007; }
    .badge { display: inline-flex; gap: 9px; align-items: center; padding: 8px 12px; border: 1px solid #9a8cff55; border-radius: 999px; color: #c9c1ff; font-size: 13px; font-weight: 650; letter-spacing: .04em; }
    .dot { width: 8px; height: 8px; border-radius: 50%; background: #8d7cff; box-shadow: 0 0 14px #9a8cff; }
    h1 { margin: 26px 0 12px; font-size: clamp(42px, 9vw, 76px); line-height: .98; letter-spacing: -.065em; }
    p { max-width: 520px; margin: 0; color: #b7bfd2; font-size: clamp(16px, 2.4vw, 19px); line-height: 1.7; }
    .card { margin-top: 34px; padding: 19px 21px; border-radius: 16px; background: #ffffff08; border: 1px solid #ffffff12; }
    .card strong { display: block; margin-bottom: 5px; font-size: 14px; }
    .card span { color: #9da8bf; font-size: 14px; line-height: 1.6; }
  </style>
</head>
<body>
  <main>
    <div class="badge"><span class="dot"></span> YOUR CREATIVE SPACE</div>
    <h1>PlayGround</h1>
    <p>A little space to experiment, make things, and see where an idea takes you.</p>
    <div class="card"><strong>Ready when you are</strong><span>This project is live. Add your own experience whenever you are ready to build.</span></div>
  </main>
</body>
</html>
'''
Path(sys.argv[1]).write_text(html, encoding='utf-8')
PY
fi

run_timed python3 - "$PROJECT_DIR" "$OUTPUT_DIR" "$WEB_DIR/deployment-output.json" <<'PY'
import json
from pathlib import Path
import sys

project = Path(sys.argv[1]).resolve()
directory = Path(sys.argv[2]).resolve()
metadata = Path(sys.argv[3])
if directory != project and project not in directory.parents:
    raise SystemExit('Built static directory must be inside the project directory.')
metadata.parent.mkdir(parents=True, exist_ok=True)
metadata.write_text(json.dumps({'project': str(project), 'directory': str(directory)}), encoding='utf-8')
PY

[[ -s "$OUTPUT_DIR/index.html" ]] || { echo "Missing or empty built page: $OUTPUT_DIR/index.html" >&2; exit 1; }
echo "Serving $OUTPUT_DIR on 0.0.0.0:$PORT"
exec /usr/bin/time -p python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$OUTPUT_DIR"
