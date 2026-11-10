// error: has no author; set `authors` on the feed or on every entry
#import "/lib.typ": atom
#atom.feed(title: "T", link: "https://x", entries: (
  atom.entry("E", link: "https://x/e", published: "2026-01-01"),
))
