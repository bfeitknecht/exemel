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
check: (fmt "--check") spell test manual

# Run the tests and compile the README examples; `--update` regenerates tests/ref first
test *flags:
    #!/usr/bin/env bash
    set -uo pipefail
    update={{ if flags == "--update" { "1" } else if flags == "" { "" } else { error("unknown flag `" + flags + "`, expected `--update`") } }}
    out=$(mktemp -d)
    trap 'rm -rf "$out" _readme-example.typ' EXIT
    failed=0
    pass() { echo "ok    $1"; }
    fail() { echo "FAIL  $1"; [ -s "$out/err" ] && sed 's/^/      /' "$out/err"; failed=1; }
    compiles() { {{ typst }} compile --root . "$@" 2>"$out/err"; }

    # Reference documents, written to disk with bundle export. These come
    # first, so that the tests below compare against updated files.
    if compiles --features bundle --format bundle --input update=1 tests/bundle/site.typ "$out/site"; then
      for name in {{ refs }}; do
        ref=tests/ref/$name.xml
        if [ -n "$update" ]; then
          cp "$out/site/$name.xml" "$ref" && echo "wrote $ref"
        elif diff -u "$ref" "$out/site/$name.xml" >"$out/err"; then
          pass "$ref"
        else
          fail "$ref is out of date; run \`just test --update\` and review the diff"
        fi
      done
    else
      fail tests/bundle/site.typ
    fi

    # Tests that must compile; they check their output with `assert`.
    for f in tests/*.typ; do
      if compiles "$f" "$out/out.pdf"; then pass "$f"; else fail "$f"; fi
    done

    # Tests that must fail with the message in their `// error:` line.
    for f in tests/fail/*.typ; do
      expected=$(sed -n 's|^// error: ||p' "$f" | head -n 1)
      if [ -z "$expected" ]; then
        : >"$out/err"; fail "$f (missing \`// error:\` line)"
      elif compiles "$f" "$out/out.pdf"; then
        fail "$f (compiled, but expected an error)"
      elif grep -qF -- "$expected" "$out/err"; then
        pass "$f"
      else
        fail "$f (expected an error containing: $expected)"
      fi
    done

    # README examples: every ```typ block that imports the package must compile.
    awk -v out="$out" '
      /^```typ$/ { n++; file = sprintf("%s/example-%02d.typ", out, n); buf = ""; inside = 1; next }
      /^```$/ && inside { if (buf ~ /@preview\/syndicate:/) printf "%s", buf > file; inside = 0; next }
      inside { buf = buf $0 "\n" }
    ' README.md
    for f in "$out"/example-*.typ; do
      name="README.md $(basename "$f" .typ)"
      sed 's|@preview/syndicate:{{ version }}|/lib.typ|' "$f" >_readme-example.typ
      if grep -q '@preview/syndicate' _readme-example.typ; then
        : >"$out/err"; fail "$name (imports a version other than {{ version }})"
      elif compiles _readme-example.typ "$out/out.pdf"; then
        pass "$name"
      else
        fail "$name"
      fi
    done

    exit $failed

# Format all Typst files with typstyle; `--check` only reports unformatted files
fmt *flags:
    {{ typstyle }} -l 100 {{ if flags == "--check" { "--check" } else if flags == "" { "-i" } else { error("unknown flag `" + flags + "`, expected `--check`") } }} {{ sources }}

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
    cp -r README.md CHANGELOG.md LICENSE typst.toml lib.typ src dist/syndicate/{{ version }}/
    @echo "Copy dist/syndicate/{{ version }} to packages/preview/syndicate/{{ version }} of a typst/packages clone."

# Install the package locally as @local/syndicate:<version>
install:
    rm -rf "{{ data_directory() }}/typst/packages/local/syndicate/{{ version }}"
    mkdir -p "{{ data_directory() }}/typst/packages/local/syndicate/{{ version }}"
    cp -r README.md CHANGELOG.md LICENSE typst.toml lib.typ src "{{ data_directory() }}/typst/packages/local/syndicate/{{ version }}/"

# Remove the local @local/syndicate:<version> installation
uninstall:
    rm -rf "{{ data_directory() }}/typst/packages/local/syndicate/{{ version }}"

# Remove build artifacts
clean:
    rm -rf dist _readme-example.typ
