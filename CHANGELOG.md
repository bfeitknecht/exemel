# Changelog

## 0.1.0 (unreleased)

First release as **syndicate**, forked from [exemel](https://github.com/wensimehrp/exemel) 0.1.0.

### Breaking changes compared to exemel

- Requires Typst 0.15 or later (exemel supported 0.13).
- The API is now organized into the modules `xml`, `atom`, `rss` and `sitemap`. See the migration table in the README.
- `to-xml` is now `xml.encode`. It takes exactly one root element (optionally surrounded by comments and processing instructions) instead of silently concatenating several documents.
- Namespace prefixes go into the tag name (`"atom:link"`). The `namespace` key now holds a namespace URI, like the output of Typst 0.15's `xml()` reader.
- `atom-encode` / `atom-post` / `atom-author` / `atom-site-id` are now `atom.feed` / `atom.entry` / `atom.author` / `atom.tag-uri`. `site-link` is now `link`, `feed-link` is now `self-link`, and `posts` is now `entries`.
- `self-link` is no longer guessed (exemel assumed `<site>/feed.xml`).
- `tz` is set once per document instead of on every entry.

### Added

- Pure Typst XML serializer: no WASM plugin and no build step. It handles arbitrarily deep trees.
- Attribute order is preserved. `none` attributes and children are omitted. Nested child arrays are flattened.
- `xml.element`, `xml.comment`, `xml.cdata`, `xml.pi`, `xml.raw` and `xml.escape`.
- `xml.decode`, which wraps Typst's built-in reader. It accepts strings, bytes or `path(..)` values, drops the reader's comment placeholders, and round trips namespaced documents through `xml.encode`.
- Validation with clear errors: XML names, forbidden characters, comment syntax, Atom's author requirement, sitemap limits, and more.
- RSS 2.0 feeds (`rss.feed`, `rss.item`, `rss.enclosure`), with automatic `atom`, `content` and `dc` namespaces.
- Sitemaps (`sitemap.urlset`, `sitemap.url`) with `hreflang` alternates, plus sitemap indexes (`sitemap.index`).
- Dates may be ISO 8601 strings as well as `datetime` values.
- Text fields accept simple Typst content, converted strictly to plain text: unsupported elements are an error instead of being dropped.
- `stylesheet`, `namespaces` and `extra` options for extending documents.
- Atom `contributors`, `rights`, `icon`, `logo`, `generator`, `language` and structured categories.
- A manual with a guide and a full reference, generated from the doc comments: [docs/manual.pdf](docs/manual.pdf).
