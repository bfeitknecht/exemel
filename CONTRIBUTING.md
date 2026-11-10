# Contributing

You need these tools:

- [Typst](https://typst.app) 0.15
- [just](https://just.systems)
- [typstyle](https://github.com/typstyle-rs/typstyle) 0.15.1
- [typos](https://github.com/crate-ci/typos)

## Recipes

| Recipe | Description |
| --- | --- |
| `just` | Show the list of recipes. |
| `just check` | Do all the checks that CI does. |
| `just test` | Run the tests and compile the README examples. |
| `just test --update` | Write `tests/ref/*.xml` again, then run the tests. Examine the diff after this step. |
| `just fmt` | Format all Typst files. |
| `just fmt --check` | Show the Typst files with a bad format, and fail if there are such files. |
| `just spell` | Find spelling errors. |
| `just manual` | Compile `docs/manual.pdf`. |
| `just package` | Put the package files into `dist/syndicate/<version>`. |
| `just install` | Install the package on this computer as `@local/syndicate:<version>`. |
| `just uninstall` | Remove the package from this computer. |
| `just clean` | Remove the files that the recipes make. |
| `just release X.Y.Z` | Release version X.Y.Z. Refer to [Releases](#releases). |

To use a different Typst compiler, set `TYPST`, for example `TYPST=~/typst-0.15.0 just test`.
To use a different typstyle, set `TYPSTYLE`.

## Tests

- The files `tests/*.typ` must compile. They use `assert` to examine their output. They also
  compare the feeds and sitemaps with the reference files in `tests/ref`.
- The files `tests/fail/*.typ` must fail with the message in their first `// error:` line.
- The files `tests/ref/*.xml` must be equal to the documents that `tests/bundle/site.typ` writes
  with bundle export. If you change the output intentionally, run `just test --update`. Then
  examine the diff.
- Each `typ` code block in the README that imports `@preview/syndicate` must compile. Thus, each
  of these blocks must be a complete example.

## Documentation

The doc comments (`///`) of the public functions use the format of
[tidy](https://typst.app/universe/package/tidy). `docs/manual.typ` makes the reference from these
comments. The manual shows the result of the code in each `examplec` block. When you change the
documentation, run `just manual` to compile the PDF again.

Write all comments and documentation in
[ASD-STE100 Simplified Technical English](https://www.asd-ste100.org):

- Write a maximum of 20 words in an instruction and 25 words in a description.
- Write one instruction in each sentence.
- Use the active voice and simple tenses.
- Use one word for one meaning. Do not use synonyms.

## Releases

### Configuration

Do these steps one time in the settings of the GitHub repository:

1. Make a classic personal access token with the scopes `public_repo` and `workflow`. The user
   of this token opens the pull requests to typst/packages.
2. Add the token as the repository secret `PACKAGES_TOKEN`.
3. Optional: add the repository variable `PACKAGES_FORK` if your fork of typst/packages has a
   different name. The default is `<repository owner>/packages`. If the fork does not exist,
   the release workflow makes it.

### Procedure

1. Write the release notes below the heading `## Unreleased` in `CHANGELOG.md`.
2. Merge all changes into `main`.
3. On `main`, run `just release X.Y.Z`.

The recipe does these steps:

1. It makes sure that the version is correct, the working tree is clean and `main` is equal to
   `origin/main`.
2. It writes the new version into `typst.toml`, the README, `docs/manual.typ` and
   `CHANGELOG.md`.
3. It runs `just check`, which also compiles the manual again.
4. It commits the changes, adds the tag `vX.Y.Z` and pushes the commit and the tag.

The tag starts the release workflow (`.github/workflows/release.yaml`). The workflow does these
steps:

1. It runs the tests and puts the package files into `dist`.
2. It makes a GitHub release with the release notes and the manual.
3. It pushes the package to the branch `syndicate-X.Y.Z` of your fork of typst/packages.
4. It opens the pull request `syndicate:X.Y.Z` to typst/packages.

The typst/packages maintainers then examine the pull request. If they ask for changes, make a
new patch release.
