#!/usr/bin/env bash
# Regenerate tests/ref/*.xml from the current implementation using bundle
# export, which writes the documents straight to disk. Review the diff!
# Set TYPST to use a specific compiler binary.
set -euo pipefail
cd "$(dirname "$0")/.."

typst=${TYPST:-typst}
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

"$typst" compile --root . --features bundle --format bundle --input update=1 \
  tests/bundle/site.typ "$out/site"
cp "$out"/site/atom.xml "$out"/site/rss.xml "$out"/site/sitemap.xml tests/ref/
