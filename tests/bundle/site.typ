// Bundle export check (run by CI): writes the reference documents as files.
//   typst compile --root . --features bundle --format bundle tests/bundle/site.typ <dir>
#import "../atom.typ" as atom-test
#import "../rss.typ" as rss-test
#import "../sitemap.typ" as sitemap-test

#asset("feed.xml", atom-test.out)
#asset("rss.xml", rss-test.out)
#asset("sitemap.xml", sitemap-test.out)
