// XML sitemaps (https://www.sitemaps.org/protocol.html).
//
// syndicate is a fork of exemel by Jeremy Gao (https://github.com/wensimehrp/exemel),
// licensed under Apache-2.0. Sitemap support was added in this fork.

#import "util.typ" as _util
#import "xml.typ" as _xml

#let _ns = "http://www.sitemaps.org/schemas/sitemap/0.9"
#let _ns-xhtml = "http://www.w3.org/1999/xhtml"
#let _max-urls = 50000
#let _changefreqs = ("always", "hourly", "daily", "weekly", "monthly", "yearly", "never")

/// A page entry for `sitemap.urlset(..)` (or a sitemap entry for `sitemap.index(..)`).
///
/// - `loc`: the canonical URL.
/// - `lastmod`: `datetime` or ISO 8601 string. Date-only values are written
///   as `YYYY-MM-DD`, values with a time as full timestamps.
/// - `changefreq`: one of `"always"`, `"hourly"`, `"daily"`, `"weekly"`,
///   `"monthly"`, `"yearly"`, `"never"`.
/// - `priority`: a number between `0` and `1`.
/// - `alternates`: translations as `(hreflang: url)`, e.g.
///   `(de: "https://example.com/de/", "x-default": "https://example.com/")`.
/// - `extra`: additional XML nodes (declare their prefixes with `namespaces`
///   on `sitemap.urlset`).
#let url(loc, lastmod: none, changefreq: none, priority: none, alternates: (:), extra: ()) = {
  if loc == none { panic("`loc` is required") }
  if changefreq != none and changefreq not in _changefreqs {
    panic("`changefreq` must be one of " + _changefreqs.map(c => "\"" + c + "\"").join(", ") + ", found " + repr(changefreq))
  }
  if priority != none and (type(priority) not in (int, float, decimal) or priority < 0 or priority > 1) {
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

#let _entries(items, what) = {
  _util.flatten(items).map(u => {
    if type(u) == str { url(u) } else { _util.expect-record(u, "sitemap.url", what, "sitemap.url") }
  })
}

#let _document(root, stylesheet, pretty) = _xml.encode((_util.stylesheet-pi(stylesheet), root), pretty: pretty)

/// A sitemap (`<urlset>`), returned as a string. Pass `sitemap.url(..)`
/// entries (or plain URL strings) as positional arguments or arrays.
///
/// - `tz`: time zone for `lastmod` values with a time, e.g. `"Z"` or `"+01:00"`.
/// - `stylesheet`: URL of an XSL or CSS stylesheet for browsers.
/// - `namespaces`: extra `(prefix: uri)` declarations for nodes in `extra`.
/// - `pretty`: indent the output (default `true`).
#let urlset(..urls, tz: "Z", stylesheet: none, namespaces: (:), pretty: true) = {
  let urls = _entries(urls.pos(), "urlset")
  if urls.len() > _max-urls {
    panic("a sitemap may contain at most 50000 URLs, found " + str(urls.len()) + "; split it and use `sitemap.index`")
  }
  let needs-xhtml = urls.any(u => u.alternates.len() > 0)
  let root = (
    tag: "urlset",
    attrs: (xmlns: _ns, "xmlns:xhtml": if needs-xhtml { _ns-xhtml }) + _util.xmlns-attrs(namespaces),
    children: urls.map(u => (
      tag: "url",
      children: (
        (tag: "loc", children: (u.loc,)),
        if u.lastmod != none { (tag: "lastmod", children: (_util.w3c(u.lastmod, tz: tz),)) },
        if u.changefreq != none { (tag: "changefreq", children: (u.changefreq,)) },
        if u.priority != none { (tag: "priority", children: (_priority(u.priority),)) },
        for (lang, href) in u.alternates {
          ((tag: "xhtml:link", attrs: (rel: "alternate", hreflang: lang, href: _util.to-text(href, field: "alternates"))),)
        },
        u.extra,
      ),
    )),
  )
  _document(root, stylesheet, pretty)
}

/// A sitemap index (`<sitemapindex>`) pointing to other sitemaps, returned as
/// a string. Pass sitemap URLs as strings or `sitemap.url(loc, lastmod: ..)`.
///
/// - `tz`: time zone for `lastmod` values with a time.
/// - `stylesheet`: URL of an XSL or CSS stylesheet for browsers.
/// - `pretty`: indent the output (default `true`).
#let index(..sitemaps, tz: "Z", stylesheet: none, pretty: true) = {
  let sitemaps = _entries(sitemaps.pos(), "index")
  if sitemaps.len() > _max-urls {
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
      children: (
        (tag: "loc", children: (s.loc,)),
        if s.lastmod != none { (tag: "lastmod", children: (_util.w3c(s.lastmod, tz: tz),)) },
      ),
    )),
  )
  _document(root, stylesheet, pretty)
}
