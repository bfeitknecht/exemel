#import "/lib.typ": sitemap
#import "posts.typ": *

#let out = sitemap.urlset(
  sitemap.url(site, changefreq: "daily", priority: 1),
  sitemap.url(
    site + "about/",
    lastmod: "2026-05-01",
    priority: 0.25,
    alternates: (de: site + "de/about/", "x-default": site + "about/"),
  ),
  posts.map(p => sitemap.url(post-url(p), lastmod: if p.updated == auto { p.published } else {
    p.updated
  })),
  site + "imprint/",
  tz: "+01:00",
)

#metadata(out) <out>
#if "update" not in sys.inputs { assert.eq(out, read("ref/sitemap.xml")) }

#let idx = sitemap.index(
  site + "sitemap-pages.xml",
  sitemap.url(site + "sitemap-posts.xml", lastmod: "2026-07-03"),
  pretty: false,
)
#assert.eq(
  idx,
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><sitemapindex xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\"><sitemap><loc>https://example.com/sitemap-pages.xml</loc></sitemap><sitemap><loc>https://example.com/sitemap-posts.xml</loc><lastmod>2026-07-03</lastmod></sitemap></sitemapindex>",
)

// No alternates → no xhtml namespace
#assert(not sitemap.urlset("https://x/").contains("xhtml"))
