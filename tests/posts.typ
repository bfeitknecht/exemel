// Shared fixture: the kind of post metadata a blog would keep, mapped to every format.
#let site = "https://example.com/"
#let posts = (
  (
    title: "Hayaku",
    slug: "hayaku-naro",
    published: datetime(year: 2026, month: 7, day: 1),
    updated: datetime(year: 2026, month: 7, day: 3, hour: 14, minute: 30, second: 0),
    summary: [Hachimi _hachimi_ -- "o namerudo"],
    html: "<p>Ashiga ashiga &amp; hayaku naro</p>",
    tags: ("umamusume", "clannad"),
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
