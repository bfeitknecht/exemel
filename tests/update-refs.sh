#!/usr/bin/env bash
# Regenerate tests/ref/*.xml from the current implementation. Review the diff!
# Set TYPST to use a specific compiler binary.
set -euo pipefail
cd "$(dirname "$0")/.."

typst=${TYPST:-typst}
for name in atom rss sitemap; do
  "$typst" eval --root . --in "tests/$name.typ" --input update=1 \
    'query(<out>).first().value' --format raw -o "tests/ref/$name.xml"
done
