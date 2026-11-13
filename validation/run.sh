#!/usr/bin/env bash
# Full validation run: app pass, two reference passes, comparison.
#   validation/run.sh                 all sites in validation/sites.yaml
#   validation/run.sh example kvk     only these slugs
set -euo pipefail
cd "$(dirname "$0")/.."

stamp=$(date +%Y%m%d-%H%M%S)
out="$PWD/validation/runs/$stamp"
mkdir -p "$out"

sites=$(uv run -q --with pyyaml python - "$@" <<'EOF'
import sys, yaml
only = set(sys.argv[1:])
sites = yaml.safe_load(open("validation/sites.yaml"))["sites"]
print(",".join(f"{s['slug']}={s['url']}" for s in sites if not only or s["slug"] in only))
EOF
)
[ -n "$sites" ] || { echo "no sites selected" >&2; exit 1; }

echo "== app pass -> $out"
flutter test integration_test/site_validation_test.dart -d macos \
  --dart-define=VSV_SITES="$sites" --dart-define=VSV_OUT="$out" \
  --dart-define=VSV_LINGER="${VSV_LINGER:-20}" \
  > "$out/app.log" 2>&1 || { echo "app pass failed, see $out/app.log" >&2; exit 1; }
grep '^VSV ' "$out/app.log" || true

echo "== reference R1"
uv run -q validation/reference.py "$out" --label R1
echo "== reference R2"
uv run -q validation/reference.py "$out" --label R2

echo "== compare"
uv run -q validation/compare.py "$out"
