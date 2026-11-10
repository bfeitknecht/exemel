version := `sed -n 's/^version = "\(.*\)"/\1/p' typst.toml`

# Run the test suite (set TYPST to use another compiler binary)
test:
    tests/run.sh

# Regenerate tests/ref/*.xml from the current implementation; review the diff!
update-refs:
    tests/update-refs.sh

# Assemble the package for submission to typst/packages
package: test
    rm -rf dist
    mkdir -p dist/syndicate/{{version}}
    cp -r README.md CHANGELOG.md LICENSE NOTICE typst.toml lib.typ src dist/syndicate/{{version}}/
