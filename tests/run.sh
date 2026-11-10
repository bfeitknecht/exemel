#!/usr/bin/env bash
# Run the test suite.
#
# - tests/*.typ must compile (they use `assert` and compare against tests/ref/*).
# - tests/fail/*.typ must fail with the message given in their `// error:` line.
#
# Set TYPST to use a specific compiler binary.
set -uo pipefail
cd "$(dirname "$0")/.."

typst=${TYPST:-typst}
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
failed=0

for f in tests/*.typ; do
  if "$typst" compile --root . "$f" "$out/out.pdf" 2>"$out/err"; then
    echo "ok    $f"
  else
    echo "FAIL  $f"
    sed 's/^/      /' "$out/err"
    failed=1
  fi
done

for f in tests/fail/*.typ; do
  expected=$(sed -n 's|^// error: ||p' "$f" | head -n 1)
  if [ -z "$expected" ]; then
    echo "FAIL  $f (missing \`// error:\` line)"
    failed=1
  elif "$typst" compile --root . "$f" "$out/out.pdf" 2>"$out/err"; then
    echo "FAIL  $f (compiled, but expected an error)"
    failed=1
  elif grep -qF -- "$expected" "$out/err"; then
    echo "ok    $f"
  else
    echo "FAIL  $f (expected error containing: $expected)"
    sed 's/^/      /' "$out/err"
    failed=1
  fi
done

exit $failed
