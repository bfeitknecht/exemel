# Changelog

## 0.1.0 (unreleased)

Initial release. Requires Typst 0.15 or later.

- XML encoding with `xml.encode`, written in pure Typst. It handles arbitrarily deep trees,
  preserves attribute order, omits `none` attributes and children, and flattens nested child
  arrays.
- Node helpers `xml.element`, `xml.comment`, `xml.cdata`, `xml.pi`, `xml.raw` and `xml.escape`.
- `xml.decode`, which wraps Typst's built-in reader. It accepts strings, bytes or `path(..)`
  values, removes the reader's comment placeholders, and round-trips namespaced documents through
  `xml.encode`.
- Atom 1.0 feeds: `atom.feed`, `atom.entry`, `atom.author` and `atom.tag-uri`.
- RSS 2.0 feeds: `rss.feed`, `rss.item` and `rss.enclosure`, with automatic `atom`, `content`
  and `dc` namespaces.
- Sitemaps: `sitemap.urlset` and `sitemap.url` with `hreflang` alternates, and sitemap indexes
  with `sitemap.index`.
- Date formatting with `rfc3339` and `rfc2822`. Dates may be `datetime` values or ISO 8601
  strings, and time zones are set once per document with `tz`.
- Text fields accept simple Typst content, converted strictly to plain text: unsupported
  elements are an error instead of being dropped.
- `stylesheet`, `namespaces` and `extra` options for extending documents.
- Validation with clear errors: XML names, forbidden characters, comment syntax, Atom's author
  requirement, sitemap limits, and more.
- A manual with a guide and a full reference: [docs/manual.pdf](docs/manual.pdf).
