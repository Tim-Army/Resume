#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-scripts/bash/set-github-project-status.sh}"

if [[ ! -f "$TARGET" ]]; then
  printf 'ERROR: Script not found: %s\n' "$TARGET" >&2
  exit 1
fi

python3 - "$TARGET" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()

pattern = re.compile(
    r"log\(\) \{\n.*?\n\}",
    re.DOTALL,
)

replacement = """log() {
  printf '[%s] %s\\n' \"$(date '+%H:%M:%S')\" \"$*\"
}"""

updated, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit("ERROR: Could not locate the log() function")

path.write_text(updated)
PY

chmod +x "$TARGET"
bash -n "$TARGET"

if grep -nF '%(' "$TARGET" >/dev/null; then
  printf 'ERROR: Unsupported printf time formatter still exists:\n' >&2
  grep -nF '%(' "$TARGET" >&2
  exit 1
fi

printf 'PASS: Patched macOS-compatible logging in %s\n' "$TARGET"
printf 'Updated log function:\n'
sed -n '/^log() {/,/^}/p' "$TARGET"
