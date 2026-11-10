# Contributing

You need [Typst](https://typst.app) 0.15, [just](https://just.systems),
[typstyle](https://github.com/typstyle-rs/typstyle) 0.15.1 and
[typos](https://github.com/crate-ci/typos). `nix develop` (or direnv) provides all of them.

## Recipes

| Recipe | Description |
| --- | --- |
| `just` | List the recipes. |
| `just check` | Run everything CI checks. |
| `just test` | Run the tests and compile the README examples. |
| `just test --update` | Regenerate `tests/ref/*.xml` first, then run the tests. Review the diff afterwards. |
| `just fmt` | Format all Typst files. |
| `just fmt --check` | Fail if any Typst file is not formatted. |
| `just spell` | Check spelling. |
| `just manual` | Build `docs/manual.pdf`. |
| `just package` | Run `check`, then assemble `dist/syndicate/<version>` for typst/packages. |
| `just install` | Install the package locally as `@local/syndicate:<version>`. |
| `just uninstall` | Remove the local installation. |
| `just clean` | Remove build artifacts. |

Set `TYPST` to use a different compiler binary, e.g. `TYPST=~/typst-0.15.0 just test`.

## Tests

- `tests/*.typ` must compile. They check outputs with `assert`, and compare the feeds and
  sitemap against the reference files in `tests/ref`.
- `tests/fail/*.typ` must fail with the message in their first `// error:` line.
- `tests/ref/*.xml` must match the documents that `tests/bundle/site.typ` writes with bundle
  export. After an intentional change to the output, run `just test --update` and review the
  diff.
- Every `typ` code block in the README that imports `@preview/syndicate` must compile, so it has
  to be a complete example.

## Documentation

Public functions are documented with [tidy](https://typst.app/universe/package/tidy) doc
comments (`///`), which `docs/manual.typ` turns into the reference. Code in `examplec` blocks is
evaluated and its result shown in the manual. Rebuild the PDF with `just manual` when the
documentation changes.

## Releasing

1. Update the version in `typst.toml`, the README, `docs/manual.typ` and `CHANGELOG.md`.
2. Run `just manual` and commit the PDF.
3. Run `just package` and copy `dist/syndicate/<version>` into a fork of
   [typst/packages](https://github.com/typst/packages), under `packages/preview/syndicate/`.
