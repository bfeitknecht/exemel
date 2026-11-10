// Writes the reference documents in tests/ref with bundle export. Refer to
// `just test --update`.

#import "../atom.typ" as atom-test
#import "../rss.typ" as rss-test
#import "../sitemap.typ" as sitemap-test

#asset("atom.xml", atom-test.out)
#asset("rss.xml", rss-test.out)
#asset("sitemap.xml", sitemap-test.out)
