// Post data, as a blog keeps it. The feed and sitemap tests use this data.
#let site = "https://example.com/"
#let posts = (
  (
    title: "Hello, world",
    slug: "hello-world",
    published: datetime(year: 2026, month: 7, day: 1),
    updated: datetime(year: 2026, month: 7, day: 3, hour: 14, minute: 30, second: 0),
    summary: [My _first_ post -- "finally"],
    html: "<p>Welcome to my <em>new</em> blog &amp; feed.</p>",
    tags: ("meta", "typst"),
  ),
  (
    title: "Typst & XML",
    slug: "typst-xml",
    published: "2026-01-15T09:00",
    updated: auto,
    summary: "Plain string summary with <angle brackets>",
    html: none,
    tags: (),
  ),
)
#let post-url(p) = site + "blog/" + p.slug + "/"
