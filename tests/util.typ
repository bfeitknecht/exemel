#import "/lib.typ": atom, rfc2822, rfc3339
#import "/src/util.typ": to-datetime, to-text

// Dates
#let d = datetime(year: 2026, month: 7, day: 1)
#let dt = datetime(year: 2026, month: 7, day: 3, hour: 14, minute: 30, second: 5)
#assert.eq(rfc3339(d), "2026-07-01T00:00:00Z")
#assert.eq(rfc3339(dt, tz: "+01:00"), "2026-07-03T14:30:05+01:00")
#assert.eq(rfc3339(dt, tz: "-0530"), "2026-07-03T14:30:05-05:30")
#assert.eq(rfc3339(dt, tz: "+00:00"), "2026-07-03T14:30:05Z")
#assert.eq(rfc2822(d), "Wed, 01 Jul 2026 00:00:00 +0000")
#assert.eq(rfc2822(dt, tz: "+01:00"), "Fri, 03 Jul 2026 14:30:05 +0100")
#assert.eq(rfc2822("2024-02-29T23:59"), "Thu, 29 Feb 2024 23:59:00 +0000")

#assert.eq(to-datetime("2026-07-01"), d)
#assert.eq(to-datetime("2026-07-03T14:30:05"), dt)
#assert.eq(to-datetime("2026-07-03 14:30"), datetime(
  year: 2026,
  month: 7,
  day: 3,
  hour: 14,
  minute: 30,
  second: 0,
))

// `tag:` URIs
#assert.eq(atom.tag-uri("example.com", d, "blog/post"), "tag:example.com,2026-07-01:blog/post")
#assert.eq(atom.tag-uri("me@example.com", "2026-01-01", ""), "tag:me@example.com,2026-01-01:")

// Conversion to plain text
#assert.eq(to-text("plain"), "plain")
#assert.eq(to-text(42), "42")
#assert.eq(to-text(sym.arrow.r), "→")
#assert.eq(to-text([Hello *bold* _emph_ `raw`]), "Hello bold emph raw")
#assert.eq(to-text([It's "quoted" -- really...]), "It's \"quoted\" – really…")
#assert.eq(
  to-text([#link("https://typst.app")[Typst] and #link("https://x.org")]),
  "Typst and https://x.org",
)
#assert.eq(to-text([#underline[u] #strike[s] #highlight[h] #smallcaps[c] H#sub[2]O]), "u s h c H2O")
#assert.eq(to-text([a \ b]), "a \n b")
#assert.eq(
  to-text({
    set text(red)
    [styled]
  }),
  "styled",
)
