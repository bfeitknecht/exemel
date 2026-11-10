// Internal helpers shared by all syndicate modules. Not part of the public API.
//
// syndicate is a fork of exemel by Jeremy Gao (https://github.com/wensimehrp/exemel),
// licensed under Apache-2.0. This file has been modified from the original.

// --- strings ---------------------------------------------------------------

/// Concatenate an array of strings (`array.join` returns `none` for empty arrays).
#let concat(parts) = if parts.len() == 0 { "" } else { parts.join() }

/// Flatten nested arrays and drop `none` entries. A single non-array value is
/// treated as a one-element array.
#let flatten(items) = {
  if type(items) != array { items = (items,) }
  let out = ()
  for item in items {
    if item == none { continue }
    if type(item) == array { out += flatten(item) } else { out.push(item) }
  }
  out
}

// --- content -> text ---------------------------------------------------------

#let _space = [ ].func()
#let _sequence = [a *b*].func()
#let _styled = { set text(red); [a] }.func()

// Elements whose plain-text form is simply the plain-text form of their `body`.
#let _wrappers = (
  strong, emph, underline, overline, strike, highlight, smallcaps,
  sub, super, link, box, block, align, pad,
)

#let _content-to-text(c, field) = {
  let f = c.func()
  if f == _space {
    " "
  } else if f == linebreak {
    "\n"
  } else if f == parbreak {
    "\n\n"
  } else if f == smartquote {
    if c.at("double", default: true) { "\"" } else { "'" }
  } else if f == metadata {
    ""
  } else if f == _sequence {
    concat(c.children.map(ch => _content-to-text(ch, field)))
  } else if f == _styled {
    _content-to-text(c.child, field)
  } else if c.has("text") and type(c.text) == str {
    // `text`, `raw`, shorthands like `--` and symbols
    c.text
  } else if _wrappers.contains(f) and c.has("body") {
    let b = c.body
    if type(b) == content { _content-to-text(b, field) } else { str(b) }
  } else {
    panic(
      "cannot convert `" + repr(f) + "` to plain text for `" + field + "`; "
        + "only plain markup (text, spaces, quotes, emphasis, links, raw, …) is supported. "
        + "Pass a string instead.",
    )
  }
}

/// Convert a value to plain text. Accepts strings, numbers, symbols and simple
/// markup. Anything that has no faithful plain-text form panics instead of
/// being silently dropped.
#let to-text(v, field: "value") = {
  let t = type(v)
  if t == str {
    v
  } else if t == int or t == float or t == decimal or t == symbol {
    str(v)
  } else if t == content {
    _content-to-text(v, field)
  } else {
    panic("`" + field + "` must be a string or content, found " + str(t))
  }
}

/// Like `to-text`, but passes `none` through.
#let opt-text(v, field: "value") = if v == none { none } else { to-text(v, field: field) }

// --- dates -------------------------------------------------------------------

#let _iso-re = regex("^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?$")

/// Turn a `datetime` or an ISO 8601 string (`2026-07-01`, `2026-07-01T14:30`,
/// `2026-07-01T14:30:00`) into a `datetime`. Time zones are configured with the
/// `tz` parameter of the document functions, not inside the string.
#let to-datetime(v, field: "date") = {
  if type(v) == datetime {
    if v.year() == none {
      panic("`" + field + "` must include a date (year, month and day)")
    }
    return v
  }
  if type(v) != str {
    panic("`" + field + "` must be a `datetime` or an ISO 8601 string, found " + str(type(v)))
  }
  let m = v.trim().match(_iso-re)
  if m == none {
    panic(
      "`" + field + "` is not a supported date: \"" + v + "\"; "
        + "use `YYYY-MM-DD`, `YYYY-MM-DDTHH:MM` or `YYYY-MM-DDTHH:MM:SS` without a time zone "
        + "(set the time zone with `tz`)",
    )
  }
  let (y, mo, d, h, mi, s) = m.captures
  if h == none {
    datetime(year: int(y), month: int(mo), day: int(d))
  } else {
    datetime(
      year: int(y), month: int(mo), day: int(d),
      hour: int(h), minute: int(mi), second: if s == none { 0 } else { int(s) },
    )
  }
}

#let opt-datetime(v, field: "date") = if v == none { none } else { to-datetime(v, field: field) }

#let has-time(dt) = dt.hour() != none

/// Fill in a missing time component with midnight.
#let with-time(dt) = if has-time(dt) { dt } else {
  datetime(year: dt.year(), month: dt.month(), day: dt.day(), hour: 0, minute: 0, second: 0)
}

/// A string that sorts chronologically.
#let sort-key(dt) = with-time(dt).display("[year][month][day][hour][minute][second]")

/// The latest of an array of datetimes, or `none`.
#let latest(dts) = {
  let dts = dts.filter(d => d != none)
  if dts.len() == 0 { none } else { dts.sorted(key: sort-key).last() }
}

#let _tz-re = regex("^([+-])(\d{2}):?(\d{2})$")

/// Parse a time zone (`"Z"`, `"+01:00"`, `"-0530"`) into `none` (UTC) or
/// `(sign, hours, minutes)`.
#let _parse-tz(tz) = {
  if type(tz) != str {
    panic("`tz` must be a string like \"Z\", \"+01:00\" or \"-0530\", found " + str(type(tz)))
  }
  let s = tz.trim()
  if s == "Z" or s == "z" or s == "UTC" or s == "GMT" { return none }
  let m = s.match(_tz-re)
  if m == none {
    panic("`tz` must look like \"Z\", \"+01:00\" or \"-0530\", found \"" + tz + "\"")
  }
  let (sign, hh, mm) = m.captures
  if int(hh) > 23 or int(mm) > 59 {
    panic("`tz` offset out of range: \"" + tz + "\"")
  }
  if int(hh) == 0 and int(mm) == 0 { none } else { (sign, hh, mm) }
}

/// Format a `datetime` as an RFC 3339 timestamp (Atom, sitemaps). Date-only
/// values get a time of `00:00:00`.
#let rfc3339(dt, tz: "Z") = {
  let dt = with-time(to-datetime(dt, field: "dt"))
  let off = _parse-tz(tz)
  dt.display("[year]-[month]-[day]T[hour]:[minute]:[second]") + if off == none { "Z" } else {
    off.at(0) + off.at(1) + ":" + off.at(2)
  }
}

/// Format a `datetime` as an RFC 2822 timestamp (RSS). Date-only values get a
/// time of `00:00:00`.
#let rfc2822(dt, tz: "Z") = {
  let dt = with-time(to-datetime(dt, field: "dt"))
  let off = _parse-tz(tz)
  dt.display("[weekday repr:short], [day] [month repr:short] [year] [hour]:[minute]:[second] ") + if off == none {
    "+0000"
  } else {
    off.at(0) + off.at(1) + off.at(2)
  }
}

/// W3C datetime as used by sitemaps: date-only values stay date-only.
#let w3c(dt, tz: "Z") = {
  let dt = to-datetime(dt, field: "lastmod")
  if has-time(dt) { rfc3339(dt, tz: tz) } else { dt.display("[year]-[month]-[day]") }
}

// --- records -----------------------------------------------------------------

/// Tag a dictionary as a record produced by one of the builder functions.
#let record(kind, fields) = (syndicate: kind) + fields

#let is-record(v, kind) = type(v) == dictionary and v.at("syndicate", default: none) == kind

#let expect-record(v, kind, field, hint) = {
  if not is-record(v, kind) {
    panic("every entry of `" + field + "` must be created with `" + hint + "`, found " + repr(v))
  }
  v
}

/// Join a base URL and a path with exactly one slash.
#let join-url(base, path) = base.trim("/", at: end) + "/" + path.trim("/", at: start)

/// A `<?xml-stylesheet?>` processing instruction for `href`, or `none`.
#let stylesheet-pi(href) = {
  if href == none { return none }
  let href = to-text(href, field: "stylesheet")
  let kind = if lower(href).ends-with(".css") { "text/css" } else { "text/xsl" }
  (pi: "xml-stylesheet", data: "type=\"" + kind + "\" href=\"" + href.replace("&", "&amp;").replace("\"", "&quot;") + "\"")
}

/// `namespaces: (prefix: uri)` → `("xmlns:prefix": uri)`.
#let xmlns-attrs(namespaces) = {
  let out = (:)
  for (prefix, uri) in namespaces {
    out.insert(if prefix == "" { "xmlns" } else { "xmlns:" + prefix }, uri)
  }
  out
}
