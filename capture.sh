#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
: "${RUNTIME_DIR:?RUNTIME_DIR must point to the OMGithub runtime}"
: "${CAPTURE_URL:?Set CAPTURE_URL to the exact preview URL}"
: "${CAPTURE_DIR:?Set CAPTURE_DIR to the evidence output directory}"

run_timed() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  /usr/bin/time -p "$@"
}

python3 - "$PROJECT_DIR" "$CAPTURE_URL" "$CAPTURE_DIR" <<'PY'
from pathlib import Path
import sys
from urllib.parse import urlparse

project = Path(sys.argv[1]).resolve()
url = urlparse(sys.argv[2])
out = Path(sys.argv[3]).resolve()
if url.scheme not in ('http', 'https') or not url.netloc:
    raise SystemExit('CAPTURE_URL must be an absolute HTTP(S) URL.')
if out == project or project in out.parents:
    raise SystemExit('CAPTURE_DIR must be outside the project source tree.')
out.mkdir(parents=True, exist_ok=True)
PY

export CAPTURE_STRICT=1
run_timed node "$RUNTIME_DIR/scripts/default-capture.mjs"
