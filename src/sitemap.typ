// XML sitemaps (https://www.sitemaps.org/protocol.html).
//
// Part of syndicate, a fork of exemel by Jeremy Gao.
// Licensed under the Apache License 2.0; see LICENSE and NOTICE.

#import "util.typ" as _util
#import "xml.typ" as _xml

#let _ns = "http://www.sitemaps.org/schemas/sitemap/0.9"
#let _ns-xhtml = "http://www.w3.org/1999/xhtml"
#let _max-entries = 50000
#let _changefreqs = ("always", "hourly", "daily", "weekly", "monthly", "yearly", "never")

/// Describes a page, for `sitemap.urlset(..)`, or a sitemap, for
/// `sitemap.index(..)`.
///
/// ```typc
/// sitemap.url(
///   "https://example.com/about/",
///   lastmod: "2026-05-01",
///   alternates: (de: "https://example.com/de/about/"),
/// )
/// ```
///
/// -> dictionary
#let url(
  /// The page's canonical URL. -> str
  loc,
  /// When the page last changed. Dates without a time are written as
  /// `YYYY-MM-DD`. -> datetime | str | none
  lastmod: none,
  /// How often the page changes: `"always"`, `"hourly"`, `"daily"`,
  /// `"weekly"`, `"monthly"`, `"yearly"` or `"never"`. -> str | none
  changefreq: none,
  /// The page's priority relative to your other pages, from `0` to `1`. -> int | float | none
  priority: none,
  /// Translations of the page as `(hreflang: url)`, e.g.
  /// `(de: "https://example.com/de/", "x-default": "https://example.com/")`. -> dictionary
  alternates: (:),
  /// Additional XML nodes appended to the entry. -> array
  extra: (),
) = {
  if changefreq != none and changefreq not in _changefreqs {
    panic(
      "`changefreq` must be one of "
        + _changefreqs.map(c => "\"" + c + "\"").join(", ")
        + ", found "
        + repr(changefreq),
    )
  }
  if (
    priority != none
      and (type(priority) not in (int, float, decimal) or priority < 0 or priority > 1)
  ) {
    panic("`priority` must be a number between 0 and 1, found " + repr(priority))
  }
  if type(alternates) != dictionary {
    panic("`alternates` must be a dictionary of `(hreflang: url)`, found " + repr(alternates))
  }
  _util.record("sitemap.url", (
    loc: _util.to-text(loc, field: "loc"),
    lastmod: _util.opt-datetime(lastmod, field: "lastmod"),
    changefreq: changefreq,
    priority: priority,
    alternates: alternates,
    extra: extra,
  ))
}

#let _priority(p) = {
  let s = str(float(p))
  if s.contains(".") { s } else { s + ".0" }
}

#let _entries(items, field) = {
  _util
    .flatten(items)
    .map(u => if type(u) == str { url(u) } else { _util.expect-record(u, "sitemap.url", field) })
}

#let _lastmod(u, tz) = if u.lastmod != none {
  (tag: "lastmod", children: (_util.w3c(u.lastmod, tz: tz),))
}

/// Generates a sitemap listing the pages of a website. Sitemaps are limited
/// to 50 000 URLs; split larger sites and list the parts with
/// `sitemap.index`.
///
/// ```examplec
/// sitemap.urlset(
///   "https://example.com/",
///   sitemap.url("https://example.com/about/", lastmod: "2026-05-01"),
/// )
/// ```
///
/// -> str
#let urlset(
  /// The pages: `sitemap.url(..)` or plain URL strings, as arguments or arrays. -> dictionary | str | array
  ..urls,
  /// The time zone of dates with a time: `"Z"` for UTC, or an offset like `"+01:00"`. -> str
  tz: "Z",
  /// The URL of an XSL or CSS stylesheet that browsers apply to the sitemap. -> str | none
  stylesheet: none,
  /// Additional namespace declarations `(prefix: uri)`, for elements in `extra`. -> dictionary
  namespaces: (:),
  /// Whether to indent the output. -> bool
  pretty: true,
) = {
  let urls = _entries(urls.pos(), "urlset")
  if urls.len() > _max-entries {
    panic(
      "a sitemap may contain at most 50000 URLs, found "
        + str(urls.len())
        + "; split it and use `sitemap.index`",
    )
  }
  let root = (
    tag: "urlset",
    attrs: (xmlns: _ns, "xmlns:xhtml": if urls.any(u => u.alternates.len() > 0) { _ns-xhtml })
      + _util.xmlns-attrs(namespaces),
    children: urls.map(u => (
      tag: "url",
      children: (
        (tag: "loc", children: (u.loc,)),
        _lastmod(u, tz),
        if u.changefreq != none { (tag: "changefreq", children: (u.changefreq,)) },
        if u.priority != none { (tag: "priority", children: (_priority(u.priority),)) },
        for (lang, href) in u.alternates {
          let href = _util.to-text(href, field: "alternates")
          ((tag: "xhtml:link", attrs: (rel: "alternate", hreflang: lang, href: href)),)
        },
        u.extra,
      ),
    )),
  )
  _xml.encode((_util.stylesheet-pi(stylesheet), root), pretty: pretty)
}

/// Generates a sitemap index, which lists several sitemaps.
///
/// ```examplec
/// sitemap.index(
///   "https://example.com/sitemap-pages.xml",
///   sitemap.url("https://example.com/sitemap-posts.xml", lastmod: "2026-07-03"),
/// )
/// ```
///
/// -> str
#let index(
  /// The sitemaps: URL strings, or `sitemap.url(loc, lastmod: ..)`. -> dictionary | str | array
  ..sitemaps,
  /// The time zone of dates with a time: `"Z"` for UTC, or an offset like `"+01:00"`. -> str
  tz: "Z",
  /// The URL of an XSL or CSS stylesheet that browsers apply to the index. -> str | none
  stylesheet: none,
  /// Whether to indent the output. -> bool
  pretty: true,
) = {
  let sitemaps = _entries(sitemaps.pos(), "index")
  if sitemaps.len() > _max-entries {
    panic("a sitemap index may contain at most 50000 sitemaps, found " + str(sitemaps.len()))
  }
  for s in sitemaps {
    if s.changefreq != none or s.priority != none or s.alternates.len() > 0 or s.extra != () {
      panic("sitemap index entries only support `loc` and `lastmod` (" + s.loc + ")")
    }
  }
  let root = (
    tag: "sitemapindex",
    attrs: (xmlns: _ns),
    children: sitemaps.map(s => (
      tag: "sitemap",
      children: ((tag: "loc", children: (s.loc,)), _lastmod(s, tz)),
    )),
  )
  _xml.encode((_util.stylesheet-pi(stylesheet), root), pretty: pretty)
}
