// error: every entry of `entries` must be created with `atom.entry`
#import "/lib.typ": atom, rss
#atom.feed(title: "T", link: "https://x", updated: "2026-01-01", entries: (rss.item("I", link: "https://x/i"),))
