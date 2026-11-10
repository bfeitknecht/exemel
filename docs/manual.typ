// The syndicate manual. Build it with `just manual`.

#import "@preview/tidy:0.4.3"
#import "/lib.typ": atom, rfc2822, rfc3339, rss, sitemap, xml

#let package = toml("/typst.toml").package
#let accent = rgb("#d9480f")
#let scope = (xml: xml, atom: atom, rss: rss, sitemap: sitemap, rfc3339: rfc3339, rfc2822: rfc2822)

// Document setup

#set document(title: "The syndicate manual", author: package.authors.map(a => a
  .split(" <")
  .first()))
#set page(
  paper: "a4",
  margin: (x: 2.2cm, y: 2.4cm),
  numbering: "1",
  header: context if here().page() > 1 {
    set text(size: 0.85em, fill: luma(110))
    [syndicate #package.version #h(1fr) #emph(package.description)]
  },
)
#set text(font: "Libertinus Serif", size: 11pt, lang: "en")
#set par(justify: true)
#set heading(numbering: (..n) => if n.pos().len() <= 2 { numbering("1.1", ..n) })
#show heading: set text(fill: accent.darken(30%))
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(1em)
  it
  v(0.5em)
}
#show link: set text(fill: accent.darken(20%))
#show raw: set text(font: "DejaVu Sans Mono", size: 0.9em)
#show raw.where(block: true): set block(
  width: 100%,
  inset: 8pt,
  radius: 3pt,
  fill: luma(247),
  stroke: 0.5pt + luma(220),
)

// Example rendering, shared by the guide and the reference. Code is
// evaluated in code mode: strings are shown as XML, other values as their
// Typst representation.

#let show-value(value) = {
  if type(value) == str {
    raw(
      value.trim("\n", at: end),
      lang: if value.starts-with("<") { "xml" } else { none },
      block: true,
    )
  } else if type(value) in (dictionary, array) {
    raw(repr(value), lang: "typc", block: true)
  } else {
    value
  }
}

#let show-example(code, inherited-scope: (:), preamble: "", mode: auto, scope: (:)) = {
  set text(size: 1em)
  let source = if type(code) == content { code.text } else { code }
  block(breakable: true, {
    raw(source, lang: "typc", block: true)
    v(-0.4em)
    align(center, text(size: 0.75em, fill: luma(130), sym.arrow.b))
    v(-0.4em)
    show-value(eval(source, mode: "code", scope: scope + inherited-scope))
  })
}

#let example(code) = show-example(code, scope: scope)

// Title page

#page(numbering: none, header: none, {
  set par(justify: false)
  v(6cm)
  text(size: 42pt, weight: "bold", fill: accent)[syndicate]
  v(0.2cm)
  text(size: 15pt)[#package.description]
  v(1cm)
  line(length: 4cm, stroke: 1.5pt + accent)
  v(0.6cm)
  text(size: 11pt)[
    Version #package.version #h(1em) · #h(1em) Typst #package.compiler or later \
    #link(package.repository) \
  ]
  v(1fr)
  text(size: 10pt, fill: luma(90))[
    syndicate encodes Typst values to XML and generates Atom 1.0 feeds, RSS 2.0 feeds and
    XML sitemaps for websites and blogs built with Typst. It is written in pure Typst, with
    no plugins. Licensed under Apache-2.0; a fork of exemel by Jeremy Gao.
  ]
})

#outline(depth: 2, indent: auto)

= Introduction

Typst can export HTML, which makes it a capable static site generator. A website rarely
consists of pages alone, though: readers subscribe to *feeds*, and search engines crawl
*sitemaps*. Both are XML documents, and Typst can read XML but not write it.

syndicate fills that gap with four modules:

#table(
  columns: (auto, 1fr),
  stroke: none,
  inset: (x: 0pt, y: 4pt),
  column-gutter: 1.5em,
  table.hline(stroke: 0.5pt),
  [*Module*], [*Contents*],
  table.hline(stroke: 0.5pt),
  [`xml`], [`encode` and `decode` for arbitrary XML, plus node helpers],
  [`atom`], [Atom 1.0 feeds (RFC 4287): `feed`, `entry`, `author`, `tag-uri`],
  [`rss`], [RSS 2.0 feeds: `feed`, `item`, `enclosure`],
  [`sitemap`], [XML sitemaps: `urlset`, `url`, and sitemap indexes with `index`],
  table.hline(stroke: 0.5pt),
)

The date formatters `rfc3339` and `rfc2822` are exported as well. Import what you need:

#raw(
  "#import \"@preview/syndicate:" + package.version + "\": xml, atom, rss, sitemap",
  lang: "typ",
  block: true,
)

Every document function returns the finished XML as a string. Importing `xml` shadows
Typst's built-in `xml()` reader in your file; use `xml.decode`, which wraps the reader, or
`std.xml`.

= Getting started

== One source of truth

Keep the metadata of your posts in one place and map it to every format:

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
  authors: "Basil",
  entries: posts.map(p => atom.entry(
    p.title,
    link: url(p),
    published: p.date,
    summary: p.summary,
  )),
)

#let rss-feed = rss.feed(
  title: "My Blog",
  link: site,
  description: "Things I write",
  self-link: site + "rss.xml",
  items: posts.map(p => rss.item(
    p.title,
    link: url(p),
    published: p.date,
    description: p.summary,
  )),
)

#let map = sitemap.urlset(site, posts.map(p => sitemap.url(url(p), lastmod: p.date)))
```

== Writing the files <writing>

By default, a Typst document produces a single output. There are two ways to get the XML
out.

*With bundle export.* Typst 0.15's experimental bundle target writes any number of files,
next to your HTML pages if you have any:

```typ
#asset("feed.xml", feed)
#asset("rss.xml", rss-feed)
#asset("sitemap.xml", map)
```

```sh
typst compile --features bundle --format bundle blog.typ site/
```

*With `typst eval`.* Expose the strings with `metadata` and extract them on the command
line. In Typst 0.15, `eval` prints JSON, so unwrap the string with `jq`:

```typ
#metadata(feed) <feed>
```

```sh
typst eval --in blog.typ 'query(<feed>).first().value' | jq -j . > feed.xml
```

== Text, dates and time zones <values>

*Text fields* accept strings, as well as Typst content made of plain markup: text, spaces,
smart quotes, `*strong*`, `_emph_`, `` `raw` ``, links, underline and the like. Feeds can
only hold plain text, so markup is stripped, and `[My _first_ post]` becomes
`My first post`. Content without a faithful plain-text form, such as equations, footnotes
or images, is an error that names the field. Nothing is dropped silently. When in doubt,
pass a string.

*Dates* are `datetime` values or ISO 8601 strings without a time zone: `"2026-07-01"`,
`"2026-07-01T14:30"` or `"2026-07-01T14:30:00"`. Strings are handy for front matter loaded
from YAML or JSON. Dates without a time get `00:00:00`, except in sitemaps, where they stay
date-only.

*Time zones* are set once per document with `tz`: `"Z"` (the default), `"+01:00"` or
`"-0530"`. Typst's `datetime` has no time zone of its own, so every date in a document is
interpreted in `tz`.

#example(```
rfc3339("2026-07-01", tz: "+02:00")
```)

= XML

== Encoding

`xml.encode` serializes a tree of nodes. Elements are dictionaries with a `tag` and
optional `attrs` and `children`, the same shape Typst's `xml()` reader produces. Text is a
string, a number or simple content, and is escaped automatically.

#example(```
xml.encode(
  (
    tag: "bookstore",
    children: (
      xml.comment(" inventory "),
      (
        tag: "book",
        attrs: (id: "bk101", category: "programming", discontinued: none),
        children: (
          (tag: "title", attrs: ("xml:lang": "en"), children: ("XML & Typst",)),
          (tag: "price", children: (44.95,)),
        ),
      ),
    ),
  ),
  pretty: true,
)
```)

- *Attributes* keep their order. `none` omits an attribute; numbers and booleans are
  converted to text.
- *Children* may contain `none`, which is skipped, and nested arrays, which are flattened,
  so `if` expressions and `.map(..)` can be used inline.
- *`pretty`* only indents elements that contain nothing but other elements. Whitespace is
  never added next to text, so text content is preserved exactly.
- *Namespace prefixes* are part of the name: `(tag: "atom:link")`. The `namespace` key holds
  a namespace URI, see @decoding.
- *Invalid input is an error:* invalid names, characters XML doesn't allow, `--` in
  comments, several root elements, misspelled keys.

Use `xml.comment`, `xml.cdata` and `xml.pi` for the other node types, and `xml.raw` to
insert pre-serialized markup verbatim.

== Decoding <decoding>

`xml.decode` parses XML into the same structure, using Typst's built-in reader. It accepts
a string, bytes, or a `path(..)` to a file. Use `path` rather than a plain file name, so the
file is found relative to your document rather than to this package.

#example(```
let doc = xml.decode("<list><item>a</item><item>b</item></list>").first()
let items = doc.children.filter(c => type(c) == dictionary)
xml.encode(
  (..doc, children: items + ((tag: "item", children: ("c",)),)),
  declaration: false,
)
```)

Decoded elements carry a `namespace` key with their namespace URI, which `xml.encode` turns
back into `xmlns` declarations, so namespaced documents round-trip:

#example(```
xml.encode(
  xml.decode("<r xmlns='urn:a' xmlns:b='urn:b'><b:x/><y/></r>"),
  declaration: false,
)
```)

Decoding inherits two limitations of the built-in reader:

- Comments and processing instructions are dropped. The reader leaves empty placeholder
  elements in their place, which `xml.decode` removes; `xml.encode` rejects them in plain
  `std.xml` output.
- Prefixes are lost: `<media:thumbnail>` comes back as `thumbnail` with the media namespace
  URI, and `xml:lang` comes back as `lang`.

= Feeds

Atom and RSS are both widely supported by feed readers. Atom is the better specified of the
two; RSS is older and more common in podcasting. Offering both costs one more call.

== Atom

#example(```
atom.feed(
  title: "My Blog",
  link: "https://example.com/",
  self-link: "https://example.com/feed.xml",
  id: atom.tag-uri("example.com", "2026-01-01", "blog"),
  authors: atom.author("Basil", email: "basil@example.com"),
  tz: "+01:00",
  entries: atom.entry(
    "Hello, world",
    link: "https://example.com/blog/hello/",
    id: atom.tag-uri("example.com", "2026-07-01", "blog/hello"),
    published: "2026-07-01",
    updated: "2026-07-03T14:30",
    summary: [My _first_ post],
    content: "<p>Welcome to my <em>new</em> blog.</p>",
    categories: ("meta", (term: "typst", label: "Typst")),
  ),
)
```)

Every feed and entry needs a permanent, unique `id`. It defaults to the `link`, which
changes when you move your site; `atom.tag-uri` builds identifiers that don't. Every entry
needs an author, set on the feed or on each entry. A string `content` is HTML source,
escaped as Atom requires; Typst content is converted to plain text.

== RSS

#example(```
rss.feed(
  title: "My Podcast",
  link: "https://example.com/",
  description: "Conversations about typesetting",
  self-link: "https://example.com/rss.xml",
  language: "en-us",
  items: rss.item(
    "Episode 1",
    link: "https://example.com/podcast/1/",
    published: "2026-07-08T06:00",
    author: (name: "Basil", email: "basil@example.com"),
    enclosure: rss.enclosure(
      "https://example.com/podcast/1.mp3",
      length: 24986239,
      type: "audio/mpeg",
    ),
  ),
)
```)

RSS's `<author>` requires an email address, so authors given only by name are written as
`<dc:creator>`. The `atom`, `content` and `dc` namespaces are declared automatically when
they're used.

= Sitemaps

A sitemap lists the pages of a website for search engines. Pages are `sitemap.url(..)`
entries or plain URL strings, passed as arguments or arrays.

#example(```
sitemap.urlset(
  sitemap.url("https://example.com/", changefreq: "daily", priority: 1),
  sitemap.url(
    "https://example.com/about/",
    lastmod: "2026-05-01",
    alternates: (de: "https://example.com/de/about/"),
  ),
  "https://example.com/imprint/",
)
```)

A sitemap holds at most 50 000 URLs. Split larger sites and list the parts with
`sitemap.index`.

= Extending documents

Every document function accepts `tz`, `stylesheet` and `pretty`:

- *`stylesheet`* adds an `<?xml-stylesheet?>` instruction, so browsers show a styled page
  instead of raw XML. Both XSL and CSS are supported.
- *`pretty`* indents the output and is on by default.

`atom.feed`, `rss.feed` and `sitemap.urlset` also accept `namespaces`, extra
`(prefix: uri)` declarations on the root element. The feeds and their entries, as well as
`sitemap.url`, accept `extra`: XML nodes appended to the element. Together, they support
extensions such as Media RSS:

#example(```
rss.feed(
  title: "Gallery",
  link: "https://example.com/",
  description: "Pictures",
  namespaces: (media: "http://search.yahoo.com/mrss/"),
  items: rss.item(
    "Sunset",
    link: "https://example.com/sunset/",
    extra: (tag: "media:content", attrs: (url: "https://example.com/sunset.jpg")),
  ),
)
```)

= Migrating from exemel

syndicate started as a fork of #link("https://github.com/wensimehrp/exemel")[exemel] and
redesigns its API:

#table(
  columns: (1fr, 1fr),
  stroke: none,
  inset: (x: 0pt, y: 4pt),
  column-gutter: 1.5em,
  table.hline(stroke: 0.5pt),
  [*exemel*], [*syndicate*],
  table.hline(stroke: 0.5pt),
  [`to-xml(value, pretty: ..)`], [`xml.encode(value, pretty: ..)`],
  [`namespace: "atom"` (a prefix)], [`tag: "atom:link"`; `namespace` holds a URI],
  [attributes sorted alphabetically], [attributes keep their order],
  [`atom-encode(site-link: .., posts: ..)`], [`atom.feed(link: .., entries: ..)`],
  [`feed-link`, guessed as `feed.xml`], [`self-link`, omitted unless given],
  [`atom-post(..)`], [`atom.entry(..)`; `id` defaults to `link`],
  [`atom-author(..)`], [`atom.author(..)`, or a string],
  [`atom-site-id(authority: .., time: .., identifier: ..)`],
  [`atom.tag-uri(authority, date, specific)`],
  [`tz` on every post], [`tz` once per document],
  [Typst 0.13 or later, WASM plugin], [Typst 0.15 or later, pure Typst],
  table.hline(stroke: 0.5pt),
)

= Reference

#let style = dictionary(tidy.styles.default) + (show-example: show-example)
#let reference(name, file, only: none) = {
  let docs = tidy.parse-module(read(file), name: name, label-prefix: name + ".", scope: scope)
  if only != none {
    docs.functions = docs.functions.filter(f => f.name in only)
    docs.variables = ()
  }
  tidy.show-module(
    docs,
    style: style,
    first-heading-level: 2,
    show-outline: true,
    sort-functions: none,
    omit-private-definitions: true,
  )
}

#reference("xml", "/src/xml.typ")
#reference("atom", "/src/atom.typ")
#reference("rss", "/src/rss.typ")
#reference("sitemap", "/src/sitemap.typ")
#reference("Dates", "/src/util.typ", only: ("rfc3339", "rfc2822"))
