// RSS 2.0 feeds (https://www.rssboard.org/rss-specification).
//
// syndicate is a fork of exemel by Jeremy Gao (https://github.com/wensimehrp/exemel),
// licensed under Apache-2.0. RSS support was added in this fork.

#import "util.typ" as _util
#import "xml.typ" as _xml

#let _ns-atom = "http://www.w3.org/2005/Atom"
#let _ns-content = "http://purl.org/rss/1.0/modules/content/"
#let _ns-dc = "http://purl.org/dc/elements/1.1/"

#let _text(tag, value) = if value == none { none } else {
  (tag: tag, children: (_util.to-text(value, field: tag),))
}

/// A media attachment for `rss.item(enclosure: ..)`, e.g. a podcast episode.
/// All three values are required by the specification.
///
/// - `url`: URL of the file.
/// - `length`: size in bytes.
/// - `type`: MIME type, e.g. `"audio/mpeg"`.
#let enclosure(url, length: none, type: none) = {
  if length == none or type == none {
    panic("`rss.enclosure` needs `url`, `length` (in bytes) and `type` (MIME type)")
  }
  if std.type(length) != int or length < 0 {
    panic("enclosure `length` must be a non-negative integer number of bytes")
  }
  _util.record("rss.enclosure", (
    url: _util.to-text(url, field: "url"),
    length: length,
    type: _util.to-text(type, field: "type"),
  ))
}

// RSS wants `email (Name)` in <author>; names without an email go to <dc:creator>.
#let _author(a) = {
  if a == none { return none }
  if type(a) == dictionary {
    if "name" not in a and "email" not in a {
      panic("`author` dictionaries need a `name` and/or an `email`, found " + repr(a))
    }
    let name = _util.opt-text(a.at("name", default: none), field: "name")
    let email = _util.opt-text(a.at("email", default: none), field: "email")
    if email == none {
      (tag: "dc:creator", children: (name,))
    } else {
      (tag: "author", children: (if name == none { email } else { email + " (" + name + ")" },))
    }
  } else {
    let s = _util.to-text(a, field: "author")
    if s.contains("@") { (tag: "author", children: (s,)) } else { (tag: "dc:creator", children: (s,)) }
  }
}

#let _category(c) = {
  if type(c) == dictionary {
    if "name" not in c { panic("category dictionaries need a `name`, found " + repr(c)) }
    (tag: "category", attrs: (domain: _util.opt-text(c.at("domain", default: none), field: "domain")), children: (_util.to-text(c.name, field: "category"),))
  } else {
    (tag: "category", children: (_util.to-text(c, field: "category"),))
  }
}

/// An RSS `<item>`, to be passed to `rss.feed(items: ..)`.
///
/// - `title`: string or simple content (`none` is allowed if `description` is set).
/// - `link`: URL of the item's web page.
/// - `guid`: unique identifier; defaults to `link`.
/// - `permalink`: whether `guid` is a URL pointing to the item; by default
///   `true` for `http(s)://` guids.
/// - `published`: `<pubDate>`, a `datetime` or ISO 8601 string.
/// - `description`: summary or full text (HTML source is allowed, it is escaped as required).
/// - `content`: full HTML content as `<content:encoded>`.
/// - `author`: `(name: .., email: ..)`, an `atom.author(..)`, or a string.
///   Authors with an email use `<author>`, names alone use `<dc:creator>`.
/// - `categories`: strings or `(name: .., domain: ..)`.
/// - `comments`: URL of the comments page.
/// - `enclosure`: an `rss.enclosure(..)`.
/// - `extra`: additional XML nodes appended to the item.
#let item(
  title,
  link: none,
  guid: auto,
  permalink: auto,
  published: none,
  description: none,
  content: none,
  author: none,
  categories: (),
  comments: none,
  enclosure: none,
  extra: (),
) = {
  if title == none and description == none {
    panic("an RSS item needs a `title` or a `description`")
  }
  let link = _util.opt-text(link, field: "link")
  let guid = if guid == auto { link } else { _util.opt-text(guid, field: "guid") }
  let permalink = if permalink == auto {
    guid != none and (guid.starts-with("http://") or guid.starts-with("https://"))
  } else {
    permalink
  }
  if enclosure != none {
    _util.expect-record(enclosure, "rss.enclosure", "enclosure", "rss.enclosure")
  }
  _util.record("rss.item", (
    title: _util.opt-text(title, field: "title"),
    link: link,
    guid: guid,
    permalink: permalink,
    published: _util.opt-datetime(published, field: "published"),
    description: _util.opt-text(description, field: "description"),
    content: _util.opt-text(content, field: "content"),
    author: _author(author),
    categories: _util.flatten(categories).map(_category),
    comments: _util.opt-text(comments, field: "comments"),
    enclosure: enclosure,
    extra: extra,
  ))
}

#let _render-item(i, tz) = (
  tag: "item",
  children: (
    _text("title", i.title),
    _text("link", i.link),
    _text("description", i.description),
    if i.content != none { (tag: "content:encoded", children: (i.content,)) },
    i.author,
    i.categories,
    _text("comments", i.comments),
    if i.enclosure != none {
      (tag: "enclosure", attrs: (url: i.enclosure.url, length: i.enclosure.length, type: i.enclosure.type))
    },
    if i.guid != none { (tag: "guid", attrs: (isPermaLink: i.permalink), children: (i.guid,)) },
    if i.published != none { (tag: "pubDate", children: (_util.rfc2822(i.published, tz: tz),)) },
    i.extra,
  ),
)

#let _uses(tree, prefix) = {
  if type(tree) == array { return tree.any(t => _uses(t, prefix)) }
  if type(tree) != dictionary or "tag" not in tree { return false }
  str(tree.tag).starts-with(prefix + ":") or _uses(tree.at("children", default: ()), prefix)
}

/// An RSS 2.0 feed document, returned as a string.
///
/// - `title`, `link`, `description`: required channel metadata.
/// - `self-link`: URL where this feed is published (recommended),
///   written as `<atom:link rel="self">`.
/// - `language`: e.g. `"en-us"`.
/// - `copyright`, `managing-editor`, `web-master`, `generator`, `docs`: optional metadata.
/// - `published`: `<pubDate>` of the channel.
/// - `updated`: `<lastBuildDate>`; defaults to the latest item `published`
///   (omitted if no item has a date). Pass `none` to omit it.
/// - `categories`: strings or `(name: .., domain: ..)`.
/// - `ttl`: minutes the feed may be cached.
/// - `image`: a URL, or `(url: .., title: .., link: .., width: .., height: ..)`.
/// - `items`: an array of `rss.item(..)`.
/// - `tz`: time zone for all dates, e.g. `"Z"` (default) or `"+01:00"`.
/// - `stylesheet`: URL of an XSL or CSS stylesheet for browsers.
/// - `namespaces`: extra `(prefix: uri)` declarations for nodes in `extra`.
/// - `extra`: additional XML nodes appended to the channel.
/// - `pretty`: indent the output (default `true`).
#let feed(
  title: none,
  link: none,
  description: none,
  self-link: none,
  language: none,
  copyright: none,
  managing-editor: none,
  web-master: none,
  published: none,
  updated: auto,
  categories: (),
  generator: none,
  docs: none,
  ttl: none,
  image: none,
  items: (),
  tz: "Z",
  stylesheet: none,
  namespaces: (:),
  extra: (),
  pretty: true,
) = {
  if title == none { panic("`title` is required") }
  if link == none { panic("`link` is required") }
  if description == none { panic("`description` is required") }
  let title = _util.to-text(title, field: "title")
  let link = _util.to-text(link, field: "link")
  let items = _util.flatten(items).map(i => _util.expect-record(i, "rss.item", "items", "rss.item"))
  let updated = if updated == auto {
    _util.latest(items.map(i => i.published))
  } else {
    _util.opt-datetime(updated, field: "updated")
  }
  let image = if image == none { none } else {
    let image = if type(image) == dictionary { image } else { (url: image) }
    (
      tag: "image",
      children: (
        _text("url", image.url),
        _text("title", image.at("title", default: title)),
        _text("link", image.at("link", default: link)),
        _text("width", image.at("width", default: none)),
        _text("height", image.at("height", default: none)),
      ),
    )
  }

  let channel = (
    tag: "channel",
    children: (
      (tag: "title", children: (title,)),
      (tag: "link", children: (link,)),
      _text("description", description),
      if self-link != none {
        (tag: "atom:link", attrs: (href: _util.to-text(self-link, field: "self-link"), rel: "self", type: "application/rss+xml"))
      },
      _text("language", language),
      _text("copyright", copyright),
      _text("managingEditor", managing-editor),
      _text("webMaster", web-master),
      if published != none { (tag: "pubDate", children: (_util.rfc2822(published, tz: tz),)) },
      if updated != none { (tag: "lastBuildDate", children: (_util.rfc2822(updated, tz: tz),)) },
      _util.flatten(categories).map(_category),
      _text("generator", generator),
      _text("docs", docs),
      _text("ttl", ttl),
      image,
      extra,
      items.map(i => _render-item(i, tz)),
    ),
  )
  let declared = (
    atom: if _uses(channel, "atom") { _ns-atom },
    content: if _uses(channel, "content") { _ns-content },
    dc: if _uses(channel, "dc") { _ns-dc },
  )
  let root = (
    tag: "rss",
    attrs: (version: "2.0") + _util.xmlns-attrs(declared) + _util.xmlns-attrs(namespaces),
    children: (channel,),
  )
  _xml.encode((_util.stylesheet-pi(stylesheet), root), pretty: pretty)
}
