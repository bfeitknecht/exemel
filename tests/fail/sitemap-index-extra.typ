// error: sitemap index entries only support `loc` and `lastmod`
#import "/lib.typ": sitemap
#sitemap.index(sitemap.url("https://x/s.xml", priority: 0.5))
