// The syndicate manual. To compile it, run `just manual`.

#import "@preview/tidy:0.4.3"
#import "/lib.typ": atom, rfc2822, rfc3339, rss, sitemap, xml

#let package = toml("/typst.toml").package
#let accent = rgb("#d9480f")
#let scope = (xml: xml, atom: atom, rss: rss, sitemap: sitemap, rfc3339: rfc3339, rfc2822: rfc2822)

// Document settings

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

// Shows examples in the guide and in the reference. Typst evaluates the code
// in code mode. The manual shows strings as XML. It shows other values in their
// Typst form.

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
    syndicate encodes Typst values to XML. It generates Atom 1.0 feeds, RSS 2.0 feeds and
    XML sitemaps for websites and blogs that you make with Typst. It is written in pure Typst
    and does not use plugins. The license is the MIT License.
  ]
})

#outline(depth: 2, indent: auto)

= Introduction

Typst can export HTML. Thus, you can use Typst to make static websites. But a website usually
has more than pages. Readers subscribe to *feeds*, and search engines read *sitemaps*. Feeds and
sitemaps are XML documents. Typst can read XML, but it cannot write XML.

syndicate has four modules that write XML:

#table(
  columns: (auto, 1fr),
  stroke: none,
  inset: (x: 0pt, y: 4pt),
  column-gutter: 1.5em,
  table.hline(stroke: 0.5pt),
  [*Module*], [*Contents*],
  table.hline(stroke: 0.5pt),
  [`xml`], [`encode` and `decode` for all XML, and functions that make nodes],
  [`atom`], [Atom 1.0 feeds (RFC 4287): `feed`, `entry`, `author`, `tag-uri`],
  [`rss`], [RSS 2.0 feeds: `feed`, `item`, `enclosure`],
  [`sitemap`], [XML sitemaps: `urlset` and `url`, and sitemap indexes with `index`],
  table.hline(stroke: 0.5pt),
)

The package also exports the date functions `rfc3339` and `rfc2822`. Import the functions that
you need:

#raw(
  "#import \"@preview/syndicate:" + package.version + "\": xml, atom, rss, sitemap",
  lang: "typ",
  block: true,
)

Each document function returns the complete XML as a string. When you import `xml`, it hides
the `xml()` reader of Typst in your file. To read XML, use `xml.decode` or `std.xml`.
`xml.decode` uses the reader of Typst.

= Start

== One data source

Keep the data of your posts in one location. Then generate all formats from this data:

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

== Write the files <writing>

Usually, a Typst document makes one output. There are two procedures to get the XML files.

*With bundle export.* Bundle export is an experimental output format of Typst 0.15. It writes
many files. If you have HTML pages, it writes the XML files together with them:

```typ
#asset("feed.xml", feed)
#asset("rss.xml", rss-feed)
#asset("sitemap.xml", map)
```

```sh
typst compile --features bundle --format bundle blog.typ site/
```

*With `typst eval`.* Put the strings into `metadata`. Then get them with `typst eval` on the
command line. In Typst 0.15, the output of `eval` is JSON. Thus, use `jq` to get the string from
the JSON:

```typ
#metadata(feed) <feed>
```

```sh
typst eval --in blog.typ 'query(<feed>).first().value' | jq -j . > feed.xml
```

== Text, dates and time zones <values>

*Text fields* accept strings. They also accept Typst content that contains only simple
markup, for example text, spaces, smart quotes, `*strong*`, `_emph_`, `` `raw` ``, links and
underline. Feeds can contain only plain text. Thus, the functions remove the markup. For
example, `[My _first_ post]` changes to `My first post`. Some content has no correct plain-text
form, for example equations, footnotes and images. For this content, the functions stop with an
error that shows the field. They do not remove content without a message. If you are not sure,
use a string.

*Dates* are `datetime` values or ISO 8601 strings without a time zone: `"2026-07-01"`,
`"2026-07-01T14:30"` or `"2026-07-01T14:30:00"`. Strings are easy to use with data from YAML
or JSON files. If a date has no time, the functions use `00:00:00`. In sitemaps, a date
without a time also has no time in the output.

*Time zones* apply to a full document. Set them with `tz`, for example `"Z"` (the default),
`"+01:00"` or `"-0530"`. A `datetime` of Typst has no time zone. Thus, the functions use `tz`
for all dates in a document.

#example(```
rfc3339("2026-07-01", tz: "+02:00")
```)

= XML

== Encode XML

`xml.encode` serializes a tree of nodes. An element is a dictionary with a `tag` and optional
`attrs` and `children`. The `xml()` reader of Typst returns the same structure. Text is a
string, a number or simple content. `xml.encode` escapes text automatically.

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

- *Attributes* keep their order. `xml.encode` does not write attributes that are `none`. It
  converts numbers and booleans to text.
- *Children* can contain `none` and nested arrays. `xml.encode` ignores `none` and flattens
  the arrays. Thus, you can use `if` expressions and `.map(..)` in the list of children.
- *`pretty`* indents only elements that contain only elements. `xml.encode` does not add
  whitespace adjacent to text. Thus, text does not change.
- *Namespace prefixes* are part of the name, for example `(tag: "atom:link")`. The key
  `namespace` contains a namespace URI. Refer to @decoding.
- *Incorrect input causes an error.* Examples are incorrect names, characters that XML
  prohibits, `--` in comments, more than one root element and keys with spelling errors.

For the other node types, use `xml.comment`, `xml.cdata` and `xml.pi`. To add markup that is
already serialized, use `xml.raw`. `xml.encode` writes this markup without changes.

== Decode XML <decoding>

`xml.decode` parses XML into the same structure. It uses the XML reader of Typst. It accepts
a string, bytes or a `path(..)` to a file. For a file, use `path`, not only the file name. Then
Typst finds the file relative to your document, not relative to this package.

#example(```
let doc = xml.decode("<list><item>a</item><item>b</item></list>").first()
let items = doc.children.filter(c => type(c) == dictionary)
xml.encode(
  (..doc, children: items + ((tag: "item", children: ("c",)),)),
  declaration: false,
)
```)

A decoded element has the key `namespace` with its namespace URI. `xml.encode` changes the URI
back to `xmlns` declarations. Thus, the encoded document keeps the namespaces:

#example(```
xml.encode(
  xml.decode("<r xmlns='urn:a' xmlns:b='urn:b'><b:x/><y/></r>"),
  declaration: false,
)
```)

`xml.decode` has two limits, because the reader of Typst has them:

- The reader removes comments and processing instructions. It puts empty placeholder elements
  in their positions. `xml.decode` removes these placeholders. If the output of `std.xml`
  contains placeholders, `xml.encode` stops with an error.
- The reader removes prefixes. For example, `<media:thumbnail>` changes to `thumbnail` with the
  media namespace URI, and `xml:lang` changes to `lang`.

= Feeds

Almost all feed readers can read Atom and RSS. The specification of Atom is more precise. RSS
is older, and podcasts use it more frequently. To publish both formats, you need only one more
function call.

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

Each feed and each entry must have a permanent, unique `id`. The default is the `link`. But
the link changes when you move your website. `atom.tag-uri` makes identifiers that do not
change. Each entry must have an author. Set the authors in the feed or in each entry. If
`content` is a string, it is HTML source. The function escapes it as Atom specifies. The
function converts Typst content to plain text.

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

In RSS, `<author>` must contain an email address. If an author has only a name, `rss.item`
writes the name as `<dc:creator>`. If the feed uses the `atom`, `content` or `dc` namespace,
`rss.feed` declares it automatically.

= Sitemaps

A sitemap lists the pages of a website for search engines. The pages are `sitemap.url(..)`
entries or URL strings. Give them as arguments or arrays.

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

A sitemap can contain a maximum of 50 000 URLs. For a larger website, divide the list into more
than one sitemap. Then list the sitemaps with `sitemap.index`.

= Extend documents

All document functions accept `tz`, `stylesheet` and `pretty`:

- *`stylesheet`* adds an `<?xml-stylesheet?>` instruction. Then browsers show a page with
  styles, not the XML source. You can use XSL or CSS.
- *`pretty`* indents the output. The default is `true`.

`atom.feed`, `rss.feed` and `sitemap.urlset` also accept `namespaces`. These are more
`(prefix: uri)` declarations on the root element. The feeds, their entries and `sitemap.url`
accept `extra`. These are XML nodes that the function adds at the end of the element. With
these two options, you can use extensions, for example Media RSS:

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
