#import "/lib.typ": rss, atom
#import "posts.typ": *

#let out = rss.feed(
  title: "Honey Drink",
  link: site,
  description: [Hachimi, _hachimi_, and hachimi],
  self-link: site + "rss.xml",
  language: "en-us",
  copyright: "© 2026 Hachimi",
  categories: ("blog",),
  generator: "syndicate",
  ttl: 60,
  image: site + "logo.png",
  tz: "+01:00",
  items: posts.map(p => rss.item(
    p.title,
    link: post-url(p),
    published: p.published,
    description: p.summary,
    content: p.html,
    author: atom.author("Hachimi", email: "namerudo@example.com"),
    categories: p.tags,
  )),
)

#metadata(out) <out>
#if "update" not in sys.inputs { assert.eq(out, read("ref/rss.xml")) }

// Minimal feed: no dates means no <lastBuildDate>, no self link means no atom namespace.
#let minimal = rss.feed(
  title: "Minimal",
  link: "https://example.org",
  description: "Nothing here",
  items: (rss.item(none, description: "Untitled", guid: "urn:x:1", author: "Someone"),),
  pretty: false,
)
#assert.eq(
  minimal,
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><rss version=\"2.0\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><channel><title>Minimal</title><link>https://example.org</link><description>Nothing here</description><item><description>Untitled</description><dc:creator>Someone</dc:creator><guid isPermaLink=\"false\">urn:x:1</guid></item></channel></rss>",
)

// Podcast enclosure, explicit guid/permalink and `updated: none`
#let pod = rss.feed(
  title: "Pod",
  link: "https://pod.example",
  description: "Episodes",
  updated: none,
  items: rss.item(
    "Episode 1",
    link: "https://pod.example/1",
    guid: "https://pod.example/1",
    permalink: false,
    published: "2026-03-01T06:00",
    enclosure: rss.enclosure("https://pod.example/1.mp3", length: 1234567, type: "audio/mpeg"),
  ),
  pretty: false,
)
#assert(pod.contains("<enclosure url=\"https://pod.example/1.mp3\" length=\"1234567\" type=\"audio/mpeg\"/>"))
#assert(pod.contains("<guid isPermaLink=\"false\">https://pod.example/1</guid>"))
#assert(not pod.contains("lastBuildDate"))
