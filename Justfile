# Development tasks for syndicate. Run `just` to list them.
#
# Set TYPST to use a specific compiler binary.

typst := env("TYPST", "typst")
typstyle := env("TYPSTYLE", "typstyle")
version := `sed -n 's/^version = "\(.*\)"/\1/p' typst.toml`
sources := "lib.typ src/*.typ tests/*.typ tests/*/*.typ docs/*.typ"
refs := "atom rss sitemap"

# List the recipes
default:
    @just --list --unsorted

# Run everything CI checks
check: fmt-check spell test readme check-refs manual

# Run the tests: tests/*.typ must compile, tests/fail/*.typ must fail with their `// error:` message
test:
    #!/usr/bin/env bash
    set -uo pipefail
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    failed=0
    for f in tests/*.typ; do
      if {{ typst }} compile --root . "$f" "$out/out.pdf" 2>"$out/err"; then
        echo "ok    $f"
      else
        echo "FAIL  $f"; sed 's/^/      /' "$out/err"; failed=1
      fi
    done
    for f in tests/fail/*.typ; do
      expected=$(sed -n 's|^// error: ||p' "$f" | head -n 1)
      if [ -z "$expected" ]; then
        echo "FAIL  $f (missing \`// error:\` line)"; failed=1
      elif {{ typst }} compile --root . "$f" "$out/out.pdf" 2>"$out/err"; then
        echo "FAIL  $f (compiled, but expected an error)"; failed=1
      elif grep -qF -- "$expected" "$out/err"; then
        echo "ok    $f"
      else
        echo "FAIL  $f (expected an error containing: $expected)"; sed 's/^/      /' "$out/err"; failed=1
      fi
    done
    exit $failed

# Compile the README's examples against the local code
readme:
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    # Every ```typ block that imports the package is a complete example.
    awk -v out="$out" '
      /^```typ$/ { n++; file = sprintf("%s/example-%02d.typ", out, n); buf = ""; inside = 1; next }
      /^```$/ && inside { if (buf ~ /@preview\/syndicate:/) printf "%s", buf > file; inside = 0; next }
      inside { buf = buf $0 "\n" }
    ' README.md
    for f in "$out"/example-*.typ; do
      sed 's|@preview/syndicate:{{ version }}|/lib.typ|' "$f" > _readme-example.typ
      if grep -q '@preview/syndicate' _readme-example.typ; then
        rm -f _readme-example.typ; echo "FAIL  README $(basename "$f" .typ) imports a version other than {{ version }}"; exit 1
      fi
      if {{ typst }} compile --root . _readme-example.typ "$out/out.pdf"; then
        echo "ok    README $(basename "$f" .typ)"
      else
        rm -f _readme-example.typ; echo "FAIL  README $(basename "$f" .typ)"; exit 1
      fi
    done
    rm -f _readme-example.typ

# Regenerate tests/ref/*.xml with bundle export (review the diff afterwards)
update-refs:
    #!/usr/bin/env bash
    set -euo pipefail
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
    {{ typst }} compile --root . --features bundle --format bundle --input update=1 tests/bundle/site.typ "$out/site"
    for name in {{ refs }}; do cp "$out/site/$name.xml" tests/ref/; done

# Fail if tests/ref/*.xml is out of date
check-refs: update-refs
    git diff --exit-code tests/ref

# Format all Typst files with typstyle
fmt:
    {{ typstyle }} -l 100 -i {{ sources }}

# Fail if any Typst file is not formatted
fmt-check:
    {{ typstyle }} -l 100 --check {{ sources }}

# Check spelling with typos
spell:
    typos

# Build the manual, docs/manual.pdf
manual:
    {{ typst }} compile --root . docs/manual.typ docs/manual.pdf

# Assemble dist/syndicate/<version> for a pull request to typst/packages
package: check
    rm -rf dist
    mkdir -p dist/syndicate/{{ version }}
    cp -r README.md CHANGELOG.md LICENSE NOTICE typst.toml lib.typ src dist/syndicate/{{ version }}/
    @echo "Copy dist/syndicate/{{ version }} to packages/preview/syndicate/{{ version }} in your typst/packages fork."

# Install the package locally as @local/syndicate:<version>
install:
    rm -rf "{{ data_directory() }}/typst/packages/local/syndicate/{{ version }}"
    mkdir -p "{{ data_directory() }}/typst/packages/local/syndicate/{{ version }}"
    cp -r README.md CHANGELOG.md LICENSE NOTICE typst.toml lib.typ src "{{ data_directory() }}/typst/packages/local/syndicate/{{ version }}/"

# Remove the local @local/syndicate:<version> installation
uninstall:
    rm -rf "{{ data_directory() }}/typst/packages/local/syndicate/{{ version }}"

# Remove build artifacts
clean:
    rm -rf dist _readme-example.typ
