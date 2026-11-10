# Development tasks for syndicate. To see the list of recipes, run `just`.
#
# To use a different Typst compiler, set the TYPST environment variable.

typst := env("TYPST", "typst")
typstyle := env("TYPSTYLE", "typstyle")
version := `sed -n 's/^version = "\(.*\)"/\1/p' typst.toml`
sources := "lib.typ src/*.typ tests/*.typ tests/*/*.typ docs/*.typ"
refs := "atom rss sitemap"
local := data_directory() / "typst/packages/local/syndicate" / version

# Show the list of recipes
default:
    @just --list --unsorted

# Do all the checks that CI does
check: (fmt "--check") spell test manual

# Run the tests and compile the README examples. Use `--update` to write tests/ref again first
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

    # Reference documents. Bundle export writes them to disk. This step is
    # first, because the tests that follow compare their output with tests/ref.
    if compiles --features bundle --format bundle --input update=1 tests/bundle/site.typ "$out/site"; then
      for name in {{ refs }}; do
        ref=tests/ref/$name.xml
        if [ -n "$update" ]; then
          cp "$out/site/$name.xml" "$ref" && echo "wrote $ref"
        elif diff -u "$ref" "$out/site/$name.xml" >"$out/err"; then
          pass "$ref"
        else
          fail "$ref is out of date; run \`just test --update\` and examine the diff"
        fi
      done
    else
      fail tests/bundle/site.typ
    fi

    # These tests must compile. They use `assert` to examine their output.
    for f in tests/*.typ; do
      if compiles "$f" "$out/out.pdf"; then pass "$f"; else fail "$f"; fi
    done

    # These tests must fail with the message in their `// error:` line.
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

    # README examples. Each ```typ block that imports the package must compile.
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

# Format all Typst files with typstyle. Use `--check` to only show the files with a bad format
fmt *flags:
    {{ typstyle }} -l 100 {{ if flags == "--check" { "--check" } else if flags == "" { "-i" } else { error("unknown flag `" + flags + "`, expected `--check`") } }} {{ sources }}

# Find spelling errors with typos
spell:
    typos

# Compile the manual to docs/manual.pdf
manual:
    {{ typst }} compile --root . docs/manual.typ docs/manual.pdf

# Put the package files into dist/syndicate/<version>
package:
    rm -rf dist
    mkdir -p dist/syndicate/{{ version }}
    cp -r README.md CHANGELOG.md LICENSE typst.toml lib.typ src dist/syndicate/{{ version }}/

# Install the package on this computer as @local/syndicate:<version>
install:
    rm -rf "{{ local }}"
    mkdir -p "{{ local }}"
    cp -r README.md CHANGELOG.md LICENSE typst.toml lib.typ src "{{ local }}/"

# Remove the package from this computer
uninstall:
    rm -rf "{{ local }}"

# Remove the files that the recipes make
clean:
    rm -rf dist _readme-example.typ

# Release a version. CI then publishes it on GitHub and opens a pull request to typst/packages
release new:
    #!/usr/bin/env bash
    set -euo pipefail
    new={{ new }}
    old={{ version }}
    error() { echo "error: $*" >&2; exit 1; }

    # Make sure that the release can start.
    [[ "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || error "use the format MAJOR.MINOR.PATCH for the version, for example 1.2.3"
    [ "$(git branch --show-current)" = main ] || error "release from the main branch"
    [ -z "$(git status --porcelain)" ] || error "commit or stash your changes first"
    git fetch --quiet --tags origin main
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || error "make your main branch equal to origin/main first"
    ! git rev-parse --quiet --verify "refs/tags/v$new" >/dev/null || error "the tag v$new exists"
    if [ "$new" != "$old" ]; then
      [ "$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -n 1)" = "$new" ] || error "use a version that is greater than $old"
    fi
    notes=$(awk '/^## / { if (found) exit } /^## Unreleased$/ { found = 1; next } found' CHANGELOG.md)
    [ -n "$(tr -d '[:space:]' <<<"$notes")" ] || error "write the release notes below '## Unreleased' in CHANGELOG.md"

    # Write the new version into the files.
    trap 'echo "The release stopped. To discard the changes, run: git checkout ." >&2' ERR
    sed -i.bak "s/^version = \"$old\"/version = \"$new\"/" typst.toml
    sed -i.bak "s|@preview/syndicate:$old|@preview/syndicate:$new|g" README.md docs/manual.typ
    sed -i.bak "s/^## Unreleased$/## $new ($(date +%Y-%m-%d))/" CHANGELOG.md
    rm -f typst.toml.bak README.md.bak docs/manual.typ.bak CHANGELOG.md.bak

    # Do the checks. This also compiles the manual again.
    just check

    git commit --quiet --all --message "Release $new"
    git tag --annotate "v$new" --message "syndicate $new"
    git push --atomic origin main "v$new"
    echo "Pushed v$new. The release workflow will open the pull request to typst/packages."
