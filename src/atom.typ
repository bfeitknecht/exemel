// Atom 1.0 (RFC 4287) feeds.
//
// syndicate is a fork of exemel by Jeremy Gao (https://github.com/wensimehrp/exemel),
// licensed under Apache-2.0. This file has been modified from the original.

#import "util.typ" as _util
#import "xml.typ" as _xml

#let _ns = "http://www.w3.org/2005/Atom"

/// Build an RFC 4151 `tag:` URI, a stable identifier for feeds and entries:
/// `tag-uri("example.com", "2026-01-01", "blog/hello")` → `tag:example.com,2026-01-01:blog/hello`.
///
/// - `authority`: a domain name or email address you controlled on `date`.
/// - `date`: a `datetime` or `YYYY-MM-DD` string.
/// - `specific`: anything that is unique under that authority and date.
#let tag-uri(authority, date, specific) = {
  let authority = _util.to-text(authority, field: "authority").trim()
  if authority == "" { panic("`authority` must not be empty") }
  let date = _util.to-datetime(date, field: "date")
  "tag:" + authority + "," + date.display("[year]-[month]-[day]") + ":" + _util.to-text(specific, field: "specific")
}

/// A person, for `authors` and `contributors`. A plain string is accepted
/// wherever a person is expected and is used as the name.
#let author(name, email: none, uri: none) = _util.record("person", (
  name: _util.to-text(name, field: "name"),
  email: _util.opt-text(email, field: "email"),
  uri: _util.opt-text(uri, field: "uri"),
))

#let _person(p, field) = {
  if type(p) == str or type(p) == content { return author(p) }
  if _util.is-record(p, "person") { return p }
  if type(p) == dictionary and "name" in p {
    return author(p.name, email: p.at("email", default: none), uri: p.at("uri", default: none))
  }
  panic("entries of `" + field + "` must be strings or created with `atom.author`, found " + repr(p))
}

#let _render-person(tag, p) = (
  tag: tag,
  children: (
    (tag: "name", children: (p.name,)),
    if p.email != none { (tag: "email", children: (p.email,)) },
    if p.uri != none { (tag: "uri", children: (p.uri,)) },
  ),
)

#let _category(c) = {
  if type(c) == dictionary {
    if "term" not in c { panic("category dictionaries need a `term`, found " + repr(c)) }
    (term: _util.to-text(c.term, field: "term"), scheme: _util.opt-text(c.at("scheme", default: none), field: "scheme"), label: _util.opt-text(c.at("label", default: none), field: "label"))
  } else {
    (term: _util.to-text(c, field: "category"), scheme: none, label: none)
  }
}

#let _render-category(c) = (tag: "category", attrs: c)

#let _content = content

#let _text-construct(tag, value, kind: "text") = {
  if value == none { return none }
  (tag: tag, attrs: (type: if kind == "text" { none } else { kind }), children: (_util.to-text(value, field: tag),))
}

/// An Atom `<entry>`, to be passed to `atom.feed(entries: ..)`.
///
/// - `title`: string or simple content.
/// - `id`: a permanent, unique IRI; defaults to `link`. See `atom.tag-uri`.
/// - `link`: URL of the entry's web page.
/// - `updated`: last significant change; defaults to `published`.
/// - `published`: first publication.
/// - `summary`: plain-text summary.
/// - `content`: the full content. Strings default to `content-type: "html"`
///   (pass the HTML source; it is escaped as required), Typst content is
///   converted to plain text and defaults to `"text"`.
/// - `authors`, `contributors`: arrays of strings or `atom.author(..)`.
/// - `categories`: strings or `(term: .., scheme: .., label: ..)`.
/// - `rights`: copyright notice.
/// - `extra`: additional XML nodes appended to the entry.
#let entry(
  title,
  id: auto,
  link: none,
  updated: auto,
  published: none,
  summary: none,
  content: none,
  content-type: auto,
  authors: (),
  contributors: (),
  categories: (),
  rights: none,
  extra: (),
) = {
  let title = _util.to-text(title, field: "title")
  let link = _util.opt-text(link, field: "link")
  let id = if id == auto {
    if link == none { panic("entry \"" + title + "\" needs an `id` or a `link`") }
    link
  } else {
    _util.to-text(id, field: "id")
  }
  if link == none and content == none {
    panic("entry \"" + title + "\" needs a `link` or `content` (RFC 4287, section 4.1.2)")
  }
  let published = _util.opt-datetime(published, field: "published")
  let updated = if updated == auto { published } else { _util.opt-datetime(updated, field: "updated") }
  if updated == none {
    panic("entry \"" + title + "\" needs `updated` or `published`")
  }
  let content-type = if content-type != auto { content-type } else if type(content) == _content { "text" } else { "html" }

  _util.record("atom.entry", (
    title: title,
    id: id,
    link: link,
    updated: updated,
    published: published,
    summary: summary,
    content: content,
    content-type: content-type,
    authors: _util.flatten(authors).map(p => _person(p, "authors")),
    contributors: _util.flatten(contributors).map(p => _person(p, "contributors")),
    categories: _util.flatten(categories).map(_category),
    rights: rights,
    extra: extra,
  ))
}

#let _render-entry(e, tz) = (
  tag: "entry",
  children: (
    (tag: "title", children: (e.title,)),
    if e.link != none { (tag: "link", attrs: (rel: "alternate", type: "text/html", href: e.link)) },
    (tag: "id", children: (e.id,)),
    (tag: "updated", children: (_util.rfc3339(e.updated, tz: tz),)),
    if e.published != none { (tag: "published", children: (_util.rfc3339(e.published, tz: tz),)) },
    e.authors.map(p => _render-person("author", p)),
    e.contributors.map(p => _render-person("contributor", p)),
    e.categories.map(_render-category),
    _text-construct("summary", e.summary),
    _text-construct("content", e.content, kind: e.content-type),
    _text-construct("rights", e.rights),
    e.extra,
  ),
)

/// An Atom 1.0 feed document, returned as a string.
///
/// - `title`, `subtitle`: strings or simple content.
/// - `link`: URL of the website.
/// - `self-link`: URL where this feed is published (recommended).
/// - `id`: a permanent, unique IRI; defaults to `link`. See `atom.tag-uri`.
/// - `updated`: defaults to the latest `updated` of all entries.
/// - `authors`: required unless every entry has its own authors.
/// - `contributors`, `categories`, `rights`, `icon`, `logo`: optional metadata.
/// - `generator`: `none`, a string, or `(name: .., uri: .., version: ..)`.
/// - `language`: written as `xml:lang`, e.g. `"en"`.
/// - `entries`: an array of `atom.entry(..)`.
/// - `tz`: time zone for all dates, e.g. `"Z"` (default) or `"+01:00"`.
/// - `stylesheet`: URL of an XSL or CSS stylesheet for browsers.
/// - `namespaces`: extra `(prefix: uri)` declarations for nodes in `extra`.
/// - `extra`: additional XML nodes appended to the feed.
/// - `pretty`: indent the output (default `true`).
#let feed(
  title: none,
  subtitle: none,
  link: none,
  self-link: none,
  id: auto,
  updated: auto,
  authors: (),
  contributors: (),
  categories: (),
  rights: none,
  icon: none,
  logo: none,
  generator: none,
  language: none,
  entries: (),
  tz: "Z",
  stylesheet: none,
  namespaces: (:),
  extra: (),
  pretty: true,
) = {
  if title == none { panic("`title` is required") }
  if link == none { panic("`link` is required") }
  let link = _util.to-text(link, field: "link")
  let id = if id == auto { link } else { _util.to-text(id, field: "id") }
  let entries = _util.flatten(entries).map(e => _util.expect-record(e, "atom.entry", "entries", "atom.entry"))
  let authors = _util.flatten(authors).map(p => _person(p, "authors"))
  if authors.len() == 0 {
    for e in entries {
      if e.authors.len() == 0 {
        panic("entry \"" + e.title + "\" has no author; set `authors` on the feed or on every entry (RFC 4287, section 4.1.1)")
      }
    }
  }
  let updated = if updated == auto {
    let latest = _util.latest(entries.map(e => e.updated))
    if latest == none { panic("cannot infer `updated` from an empty feed; pass `updated`") }
    latest
  } else {
    _util.to-datetime(updated, field: "updated")
  }
  let generator = if generator == none { none } else if type(generator) == dictionary {
    (tag: "generator", attrs: (uri: generator.at("uri", default: none), version: generator.at("version", default: none)), children: (_util.to-text(generator.name, field: "generator"),))
  } else {
    (tag: "generator", children: (_util.to-text(generator, field: "generator"),))
  }

  let root = (
    tag: "feed",
    attrs: (xmlns: _ns, "xml:lang": _util.opt-text(language, field: "language")) + _util.xmlns-attrs(namespaces),
    children: (
      _text-construct("title", title),
      _text-construct("subtitle", subtitle),
      (tag: "link", attrs: (rel: "alternate", type: "text/html", href: link)),
      if self-link != none { (tag: "link", attrs: (rel: "self", type: "application/atom+xml", href: _util.to-text(self-link, field: "self-link"))) },
      (tag: "id", children: (id,)),
      (tag: "updated", children: (_util.rfc3339(updated, tz: tz),)),
      authors.map(p => _render-person("author", p)),
      _util.flatten(contributors).map(p => _render-person("contributor", _person(p, "contributors"))),
      _util.flatten(categories).map(c => _render-category(_category(c))),
      generator,
      if icon != none { (tag: "icon", children: (_util.to-text(icon, field: "icon"),)) },
      if logo != none { (tag: "logo", children: (_util.to-text(logo, field: "logo"),)) },
      _text-construct("rights", rights),
      extra,
      entries.map(e => _render-entry(e, tz)),
    ),
  )
  _xml.encode((_util.stylesheet-pi(stylesheet), root), pretty: pretty)
}
