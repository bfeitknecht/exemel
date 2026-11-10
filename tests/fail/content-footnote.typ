// error: cannot convert `footnote` to plain text for `description`
#import "/lib.typ": rss
#rss.item("I", description: [See#footnote[here]])
