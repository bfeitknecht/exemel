# syndicate

Encode Typst values to XML and generate **Atom 1.0** feeds, **RSS 2.0** feeds and **XML sitemaps** for your Typst-built website or blog. Written in pure Typst, with no plugins. Requires Typst 0.15 or later.

```typ
#import "@preview/syndicate:0.1.0": xml, atom, rss, sitemap
```

The package is made of four modules:

| Module    | Functions                                                     |
| --------- | ------------------------------------------------------------- |
| `xml`     | `encode`, `decode`, `element`, `comment`, `cdata`, `pi`, `raw`, `escape` |
| `atom`    | `feed`, `entry`, `author`, `tag-uri`                          |
| `rss`     | `feed`, `item`, `enclosure`                                   |
| `sitemap` | `urlset`, `url`, `index`                                      |

The date helpers `rfc3339` and `rfc2822` are exported at the top level.

> [!NOTE]
> Typst can read XML on its own, but it can't write it; that's what `xml.encode` is for. Importing `xml` shadows the built-in `xml()` reader in your file. Use `xml.decode`, which wraps the reader, or `std.xml`.

## Quick start

Keep your post metadata in one place and map it to every format:

```typ
#import "@preview/syndicate:0.1.0": atom, rss, sitemap

#let site = "https://example.com/"
#let posts = (
  (
    title: "Hello, world",
    slug: "hello-world",
    date: datetime(year: 2026, month: 7, day: 1),
    summary: [My _first_ post],
  ),
  (title: "Second post", slug: "second", date: "2026-07-14T09:30", summary: "More things"),
)
#let url(p) = site + "blog/" + p.slug + "/"

#let feed = atom.feed(
  title: "My Blog",
  link: site,
  self-link: site + "feed.xml",
  authors: (atom.author("Basil", uri: site),),
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

#metadata(feed) <feed>
#metadata(rss-feed) <rss>
#metadata(map) <sitemap>
```

Each document function returns the finished XML as a string.

## Writing the files

Typst documents can't write arbitrary files by default. There are two ways to get the XML out.

**With bundle export:** Typst 0.15's experimental bundle target writes files directly, next to your HTML pages if you have any:

```typ
#asset("feed.xml", feed)
#asset("rss.xml", rss-feed)
#asset("sitemap.xml", map)
```

```sh
typst compile --features bundle --format bundle blog.typ site/
```

**With `typst eval`:** expose the strings with `metadata` (as in the quick start) and extract them on the command line. In Typst 0.15, `eval` prints JSON, so unwrap the string with [`jq`](https://jqlang.org):

```sh
typst eval --in blog.typ 'query(<feed>).first().value' | jq -j . > feed.xml
```

## Text, dates and time zones

**Text fields** accept strings, plus Typst content made of plain markup: text, spaces, smart quotes, `*strong*`, `_emph_`, `` `raw` ``, links, underline and the like. Feeds can only hold plain text, so markup is stripped: `[My _first_ post]` becomes `My first post`. Content that has no faithful plain-text form, such as equations, footnotes or images, makes the call fail with an error naming the field. Nothing is dropped silently. When in doubt, pass a string.

**Dates** are `datetime` values or ISO 8601 strings without a time zone: `"2026-07-01"`, `"2026-07-01T14:30"` or `"2026-07-01T14:30:00"`. Strings are handy for front matter loaded from YAML or JSON. Date-only values are written with a time of `00:00:00`, except in sitemaps, where they stay date-only.

**Time zones** are set once per document with `tz`: `"Z"` (the default), `"+01:00"` or `"-0530"`. Typst's `datetime` has no time zone of its own, so every date in the document is interpreted in `tz`.

## XML

`xml.encode(root, pretty: false, indent: 2, declaration: true)` serializes a tree of nodes:

- **Elements** are dictionaries `(tag: "name", attrs: (..), children: (..))`, the same shape Typst's `xml()` reader produces. `attrs` and `children` are optional. You can also build them with `xml.element(tag, attrs: (..), ..children)`.
- **Text** is a string, a number or simple content. It is escaped automatically.
- **`xml.comment(..)`, `xml.cdata(..)` and `xml.pi(target, data)`** create comments, CDATA sections and processing instructions. **`xml.raw(..)`** inserts pre-serialized markup verbatim.

```typ
#import "@preview/syndicate:0.1.0": xml

#xml.encode(
  (
    tag: "bookstore",
    children: (
      xml.comment(" inventory "),
      (
        tag: "book",
        attrs: (id: "bk101", category: "programming", discontinued: none),
        children: (
          (tag: "title", attrs: ("xml:lang": "en"), children: ("XML Developer's Guide",)),
          (tag: "price", children: (44.95,)),
        ),
      ),
    ),
  ),
  pretty: true,
)
```

Details:

- **Attributes** keep their order. A value of `none` omits the attribute. Numbers and booleans are converted to text.
- **Children** may contain `none` (skipped) and nested arrays (flattened), so `if` expressions and `.map(..)` can be used inline.
- **`pretty: true`** only indents elements that contain nothing but other elements. Whitespace is never added around text, so text content is preserved exactly.
- **`root`** may also be an array: comments and processing instructions around exactly one root element.
- **`declaration`** is `true` for `<?xml version="1.0" encoding="UTF-8"?>`, `false` for none, or a custom string.
- **Namespace prefixes** are written into the name, e.g. `(tag: "atom:link")`. An element's `namespace` key holds a namespace URI (see below).
- **Invalid input fails with an error:** invalid names, characters XML doesn't allow, `--` in comments, multiple root elements, misspelled keys.

`xml.decode(source)` parses XML into the same structure, using Typst's built-in reader. Pass a string, bytes, or a `path(..)` to a file. Use `path` rather than a plain file name so the file is found relative to your document, not relative to this package:

```typ
#import "@preview/syndicate:0.1.0": xml

#let catalog = xml.decode(path("catalog.xml")).first()
#let books = catalog.children.filter(c => type(c) == dictionary and c.tag == "book")

// Modify and write back
#xml.encode((..catalog, children: books.filter(b => b.attrs.at("id") != "bk102")))
```

Decoded elements carry a `namespace` key with their namespace URI. `xml.encode` turns it back into `xmlns` declarations, so namespaced documents round trip. The built-in reader has limitations that decoding inherits:

- Comments and processing instructions are dropped. `xml.decode` removes the empty placeholder elements the reader produces for them; plain `std.xml` output still contains them, and `xml.encode` rejects them.
- Prefixes are lost: `<media:thumbnail>` comes back as `thumbnail` with the media namespace URI, and `xml:lang` comes back as `lang`.

## Atom

```typ
#import "@preview/syndicate:0.1.0": atom

#atom.feed(
  title: "Honey Drink",
  subtitle: [Hachimi, _hachimi_, and hachimi],
  link: "https://example.com/",
  self-link: "https://example.com/feed.xml",
  id: atom.tag-uri("example.com", "2026-01-01", "blog"),
  authors: (atom.author("Hachimi", email: "hachimi@example.com"),),
  tz: "+01:00",
  entries: (
    atom.entry(
      "Hayaku",
      link: "https://example.com/blog/hayaku/",
      id: atom.tag-uri("example.com", "2026-07-01", "blog/hayaku"),
      published: "2026-07-01",
      updated: "2026-07-03T14:30",
      summary: "Hachimi hachimi hachimi",
      content: "<p>Ashiga ashiga <em>hayaku</em> naro</p>",
      categories: ("umamusume", (term: "typst", label: "Typst")),
    ),
  ),
)
```

`atom.feed(..)` builds the `<feed>` document:

- **Required:** `title` and `link` (the website).
- **`id`** is a permanent identifier and defaults to `link`. `atom.tag-uri(authority, date, specific)` builds an [RFC 4151](https://www.rfc-editor.org/rfc/rfc4151) `tag:` URI that survives URL changes.
- **`self-link`** is the URL of the feed itself. It's recommended.
- **`updated`** defaults to the latest `updated` of all entries.
- **`authors`** is required unless every entry has its own. Accepts strings or `atom.author(name, email: .., uri: ..)`.
- **Optional:** `subtitle`, `contributors`, `categories`, `rights`, `icon`, `logo`, `generator` (a string or `(name: .., uri: .., version: ..)`), and `language` (written as `xml:lang`).
- **Shared options:** `tz`, `stylesheet`, `namespaces`, `extra` and `pretty` (see [Common options](#common-options)).

`atom.entry(title, ..)` describes an `<entry>`:

- **`link`** is the entry's web page. **`id`** defaults to it.
- **`published`** and **`updated`**: `updated` defaults to `published`, and at least one is required.
- **`summary`** is plain text.
- **`content`** is the full content. Strings are treated as HTML source (`content-type: "html"`) and escaped as Atom requires. Typst content is converted to plain text (`"text"`). Override with `content-type`.
- **Optional:** `authors`, `contributors`, `categories` (strings or `(term: .., scheme: .., label: ..)`), `rights` and `extra`.

## RSS

```typ
#import "@preview/syndicate:0.1.0": rss

#rss.feed(
  title: "Honey Drink",
  link: "https://example.com/",
  description: "Hachimi, hachimi, and hachimi",
  self-link: "https://example.com/rss.xml",
  language: "en-us",
  items: (
    rss.item(
      "Hayaku",
      link: "https://example.com/blog/hayaku/",
      published: "2026-07-01",
      description: "Hachimi hachimi hachimi",
      content: "<p>Ashiga ashiga <em>hayaku</em> naro</p>",
      author: (name: "Hachimi", email: "hachimi@example.com"),
      categories: ("umamusume",),
    ),
    rss.item(
      "Episode 1",
      link: "https://example.com/podcast/1/",
      published: "2026-07-08T06:00",
      enclosure: rss.enclosure("https://example.com/podcast/1.mp3", length: 24986239, type: "audio/mpeg"),
    ),
  ),
)
```

`rss.feed(..)` builds the `<rss version="2.0">` document:

- **Required:** `title`, `link` and `description`.
- **`self-link`** is written as `<atom:link rel="self">` and is recommended.
- **`updated`** (`<lastBuildDate>`) defaults to the latest item date. Pass `none` to omit it.
- **Optional:** `language`, `copyright`, `managing-editor`, `web-master`, `published`, `categories`, `generator`, `docs`, `ttl`, and `image` (a URL or `(url: .., title: .., link: .., width: .., height: ..)`).
- **Shared options:** `tz`, `stylesheet`, `namespaces`, `extra` and `pretty` (see [Common options](#common-options)).

`rss.item(title, ..)` describes an `<item>`. `title` may be `none` if there is a `description`.

- **`link`** is the item's web page.
- **`guid`** defaults to `link`. **`permalink`** defaults to `true` for `http(s)://` guids.
- **`published`** becomes `<pubDate>`.
- **`description`** is a summary or the full text. **`content`** is full HTML, written as `<content:encoded>`.
- **`author`** is `(name: .., email: ..)`, an `atom.author(..)` or a string. Authors with an email use `<author>`. Names alone use `<dc:creator>`, because RSS's `<author>` requires an email.
- **Optional:** `categories` (strings or `(name: .., domain: ..)`), `comments`, `enclosure` (from `rss.enclosure(url, length: .., type: ..)`) and `extra`.

The `atom`, `content` and `dc` namespaces are declared automatically when they're used.

## Sitemaps

```typ
#import "@preview/syndicate:0.1.0": sitemap

#sitemap.urlset(
  sitemap.url("https://example.com/", changefreq: "daily", priority: 1.0),
  sitemap.url(
    "https://example.com/about/",
    lastmod: "2026-05-01",
    alternates: (de: "https://example.com/de/about/", "x-default": "https://example.com/about/"),
  ),
  "https://example.com/imprint/",
)
```

`sitemap.urlset(..urls)` takes `sitemap.url(..)` entries or plain URL strings, either as arguments or in arrays.

`sitemap.url(loc, ..)` accepts:

- **`lastmod`:** date-only values stay `YYYY-MM-DD`.
- **`changefreq`:** `"always"`, `"hourly"`, `"daily"`, `"weekly"`, `"monthly"`, `"yearly"` or `"never"`.
- **`priority`:** a number from 0 to 1.
- **`alternates`:** translations as `(hreflang: url)`. They're written as `<xhtml:link rel="alternate">`, and the `xhtml` namespace is declared automatically.
- **`extra`:** additional XML nodes.

`sitemap.index(..sitemaps)` builds a `<sitemapindex>` from URL strings or `sitemap.url(loc, lastmod: ..)`. Sitemaps are limited to 50 000 URLs; split larger sites and point to the parts from an index.

## Common options

Every document function (`atom.feed`, `rss.feed`, `sitemap.urlset`, `sitemap.index`) accepts:

- **`tz`:** the time zone for all dates.
- **`stylesheet`:** the URL of an XSL or CSS stylesheet, so browsers show a styled page instead of raw XML.
- **`pretty`:** indent the output (default `true`).

`atom.feed`, `rss.feed` and `sitemap.urlset` also accept:

- **`namespaces`:** extra `(prefix: uri)` declarations on the root element.
- **`extra`:** additional XML nodes to append. `sitemap.urlset` has no `extra` of its own; use the `extra` of `sitemap.url(..)`.

Use the two together for extensions such as Media RSS:

```typ
#import "@preview/syndicate:0.1.0": rss

#rss.feed(
  title: "Gallery",
  link: "https://example.com/",
  description: "Pictures",
  namespaces: (media: "http://search.yahoo.com/mrss/"),
  items: (
    rss.item("Sunset", link: "https://example.com/sunset/", extra: (
      (tag: "media:content", attrs: (url: "https://example.com/sunset.jpg", medium: "image")),
    )),
  ),
)
```

## Migrating from exemel

syndicate started as a fork of [exemel](https://github.com/wensimehrp/exemel) and changes its API:

| exemel                                    | syndicate                                                         |
| ----------------------------------------- | ----------------------------------------------------------------- |
| `to-xml(value, pretty: ..)`               | `xml.encode(value, pretty: ..)`                                   |
| `namespace: "atom"` (a prefix)            | `tag: "atom:link"`; `namespace` now holds a URI                   |
| attributes sorted alphabetically          | attributes keep their order; `none` omits them                    |
| `atom-encode(site-link: .., posts: ..)`   | `atom.feed(link: .., entries: ..)`                                |
| `feed-link` (guessed as `feed.xml`)       | `self-link` (omitted unless given)                                |
| `atom-post(..)`                           | `atom.entry(..)`; `id` defaults to `link`                         |
| `atom-author(..)`                         | `atom.author(..)`, or just a string                               |
| `atom-site-id(authority: .., time: .., identifier: ..)` | `atom.tag-uri(authority, date, specific)`           |
| `tz` on every post                        | `tz` once on the document                                         |
| Typst 0.13 or later                       | Typst 0.15 or later                                               |

The Rust/WASM plugin is gone, so there is nothing to build.

## Development

```sh
just test         # run tests/*.typ and the expected failures in tests/fail/
just update-refs  # regenerate tests/ref/*.xml after intentional output changes
just package      # assemble dist/syndicate/<version> for typst/packages
```

`nix develop` (or direnv) provides `typst` and `just`. CI runs the tests on Typst 0.15.0 and the latest release, and checks that the reference files written by bundle export are up to date.

## License

Apache-2.0. syndicate is a fork of [exemel](https://github.com/wensimehrp/exemel) by Jeremy Gao. See [NOTICE](NOTICE).
