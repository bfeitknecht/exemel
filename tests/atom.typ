#import "/lib.typ": atom
#import "posts.typ": *

#let me = atom.author("Hachimi", email: "namerudo@example.com", uri: "https://example.com/ashiga")

#let out = atom.feed(
  title: "Honey Drink",
  subtitle: [Hachimi, _hachimi_, and hachimi],
  link: site,
  self-link: site + "feed.xml",
  id: atom.tag-uri("example.com", "2026-01-01", "blog"),
  authors: (me,),
  contributors: ("Basil",),
  categories: ("blog", (term: "typst", label: "Typst", scheme: "https://typst.app")),
  rights: "© 2026 Hachimi",
  generator: (name: "syndicate", uri: "https://github.com/bfeitknecht/exemel", version: "0.1.0"),
  icon: site + "favicon.ico",
  language: "en",
  stylesheet: "/feed.xsl",
  tz: "+01:00",
  entries: posts.map(p => atom.entry(
    p.title,
    link: post-url(p),
    id: atom.tag-uri("example.com", p.published, "blog/" + p.slug),
    published: p.published,
    updated: p.updated,
    summary: p.summary,
    content: p.html,
    categories: p.tags,
  )),
)

#metadata(out) <out>
#if "update" not in sys.inputs { assert.eq(out, read("ref/atom.xml")) }

// Entry-level authors make feed-level authors optional; `updated` is inferred.
#let minimal = atom.feed(
  title: "Minimal",
  link: "https://example.org",
  entries: atom.entry("Only", link: "https://example.org/only", published: "2026-02-03", authors: "Someone"),
  pretty: false,
)
#assert.eq(
  minimal,
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns=\"http://www.w3.org/2005/Atom\"><title>Minimal</title><link rel=\"alternate\" type=\"text/html\" href=\"https://example.org\"/><id>https://example.org</id><updated>2026-02-03T00:00:00Z</updated><entry><title>Only</title><link rel=\"alternate\" type=\"text/html\" href=\"https://example.org/only\"/><id>https://example.org/only</id><updated>2026-02-03T00:00:00Z</updated><published>2026-02-03T00:00:00Z</published><author><name>Someone</name></author></entry></feed>",
)

// Typst content as entry content becomes plain text with type="text".
#let e = atom.entry("T", link: "https://x", updated: "2026-01-01", content: [Some *content*])
#assert.eq(e.content-type, "text")

// Custom namespaces and extra nodes
#let ext = atom.feed(
  title: "Ext",
  link: "https://x",
  updated: "2026-01-01",
  namespaces: (media: "http://search.yahoo.com/mrss/"),
  extra: ((tag: "media:thumbnail", attrs: (url: "https://x/t.png")),),
  pretty: false,
)
#assert(ext.contains("xmlns:media=\"http://search.yahoo.com/mrss/\""))
#assert(ext.contains("<media:thumbnail url=\"https://x/t.png\"/>"))
