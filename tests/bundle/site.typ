// Writes the reference documents as files via bundle export (see tests/update-refs.sh):
//   typst compile --root . --features bundle --format bundle --input update=1 tests/bundle/site.typ <dir>
#import "../atom.typ" as atom-test
#import "../rss.typ" as rss-test
#import "../sitemap.typ" as sitemap-test

#asset("atom.xml", atom-test.out)
#asset("rss.xml", rss-test.out)
#asset("sitemap.xml", sitemap-test.out)
