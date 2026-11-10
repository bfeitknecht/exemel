# syndicate

Generate **Atom feeds**, **RSS feeds** and **sitemaps** for websites built with Typst, and
encode any Typst value to **XML**. Written in pure Typst, with no plugins.

The [manual](docs/manual.pdf) covers everything in detail, with a guide and a full
reference.

## Quick start

Keep the metadata of your posts in one place and turn it into every format:

```typ
#import "@preview/syndicate:0.1.0": atom, rss, sitemap

#let site = "https://example.com/"
#let posts = (
  (title: "Hello, world", slug: "hello", date: "2026-07-01", summary: [My _first_ post]),
  (title: "Second post", slug: "second", date: "2026-07-14T09:30", summary: "More things"),
)
#let url(post) = site + "blog/" + post.slug + "/"

#let feed = atom.feed(
  title: "My Blog",
  link: site,
  self-link: site + "feed.xml",
  authors: "Basil",
  entries: posts.map(p => atom.entry(p.title, link: url(p), published: p.date, summary: p.summary)),
)

#let rss-feed = rss.feed(
  title: "My Blog",
  link: site,
  description: "Things I write",
  self-link: site + "rss.xml",
  items: posts.map(p => rss.item(p.title, link: url(p), published: p.date, description: p.summary)),
)

#let map = sitemap.urlset(site, posts.map(p => sitemap.url(url(p), lastmod: p.date)))
```

Every document function returns the finished XML as a string. The Atom feed above starts like
this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>My Blog</title>
  <link rel="alternate" type="text/html" href="https://example.com/"/>
  <link rel="self" type="application/atom+xml" href="https://example.com/feed.xml"/>
  <id>https://example.com/</id>
  <updated>2026-07-14T09:30:00Z</updated>
  <author>
    <name>Basil</name>
  </author>
  <entry>
    <title>Hello, world</title>
    ...
```

## Writing the files

**With bundle export**, Typst 0.15's experimental target for multi-file output, the XML is
written next to your HTML pages:

```typ
#asset("feed.xml", feed)
#asset("rss.xml", rss-feed)
#asset("sitemap.xml", map)
```

```sh
typst compile --features bundle --format bundle blog.typ site/
```

**With `typst eval`**, expose the string with `#metadata(feed) <feed>` and extract it.
`eval` prints JSON, so unwrap the string with `jq`:

```sh
typst eval --in blog.typ 'query(<feed>).first().value' | jq -j . > feed.xml
```

## Overview

```typ
#import "@preview/syndicate:0.1.0": xml, atom, rss, sitemap, rfc3339, rfc2822
```

| Definition | Description |
| --- | --- |
| `atom.feed(..)` | An Atom 1.0 feed (RFC 4287). |
| `atom.entry(title, ..)` | An entry of an Atom feed. |
| `atom.author(name, ..)` | A person, with optional email and URI. Plain strings work too. |
| `atom.tag-uri(authority, date, specific)` | A permanent `tag:` URI (RFC 4151) to use as an ID. |
| `rss.feed(..)` | An RSS 2.0 feed. |
| `rss.item(title, ..)` | An item of an RSS feed. |
| `rss.enclosure(url, length: .., type: ..)` | A media attachment, such as a podcast episode. |
| `sitemap.urlset(..urls)` | A sitemap. |
| `sitemap.url(loc, ..)` | A page of a sitemap, with `lastmod`, `changefreq`, `priority` and translations. |
| `sitemap.index(..sitemaps)` | A sitemap index, listing several sitemaps. |
| `xml.encode(root, ..)` | Serializes a tree of nodes to XML. |
| `xml.decode(source)` | Parses XML from a string, bytes or `path(..)` into the same tree. |
| `xml.element(tag, ..)` | An element node, as an alternative to writing the dictionary. |
| `xml.comment(body)` | A comment node. |
| `xml.cdata(body)` | A CDATA section. |
| `xml.pi(target, data)` | A processing instruction. |
| `xml.raw(body)` | Pre-serialized markup, written verbatim. |
| `xml.escape(text)` | Escapes text for XML. |
| `rfc3339(dt, tz: ..)` | Formats a date as used by Atom and sitemaps. |
| `rfc2822(dt, tz: ..)` | Formats a date as used by RSS. |

A few conventions apply throughout:

- **Text** can be a string or simple markup like `[My _first_ post]`, which becomes plain text.
  Markup without a plain-text form, such as an equation, is an error rather than silently
  dropped.
- **Dates** are `datetime` values or ISO 8601 strings like `"2026-07-01"` or
  `"2026-07-01T14:30"`.
- **Time zones** are set once per document with `tz`, e.g. `tz: "+01:00"`. The default is UTC.
- **Extensions** are supported through `namespaces` and `extra` on documents and entries, and
  `stylesheet` makes browsers show a styled page instead of raw XML.

## XML

Elements are dictionaries with a `tag` and optional `attrs` and `children`, the same shape
Typst's built-in `xml()` reader produces. Text is escaped automatically, attributes keep their
order, and `none` attributes and children are omitted.

```typ
#import "@preview/syndicate:0.1.0": xml

#xml.encode(
  (
    tag: "book",
    attrs: (id: "bk101", lang: none),
    children: (
      (tag: "title", children: ("XML & Typst",)),
      (tag: "price", children: (44.95,)),
    ),
  ),
  pretty: true,
)
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<book id="bk101">
  <title>XML &amp; Typst</title>
  <price>44.95</price>
</book>
```

`xml.decode` reads XML into the same structure, so documents can be modified and written back.
Importing `xml` shadows the built-in `xml()` reader; it remains available as `std.xml`.

## Migrating from exemel

syndicate is a fork of [exemel](https://github.com/wensimehrp/exemel) with a redesigned API:

| exemel | syndicate |
| --- | --- |
| `to-xml(value, pretty: ..)` | `xml.encode(value, pretty: ..)` |
| `namespace: "atom"` (a prefix) | `tag: "atom:link"`; `namespace` holds a URI |
| `atom-encode(site-link: .., feed-link: .., posts: ..)` | `atom.feed(link: .., self-link: .., entries: ..)` |
| `atom-post(..)`, `atom-author(..)` | `atom.entry(..)`, `atom.author(..)` |
| `atom-site-id(authority: .., time: .., identifier: ..)` | `atom.tag-uri(authority, date, specific)` |
| `tz` on every post | `tz` once per document |

## License

Apache-2.0. syndicate is a fork of [exemel](https://github.com/wensimehrp/exemel) by Jeremy
Gao; see [NOTICE](NOTICE).
