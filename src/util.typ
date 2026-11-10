// Internal helpers shared by all modules. Not part of the public API, except
// for `rfc3339` and `rfc2822`, which `lib.typ` re-exports.

// Arrays and strings

/// Concatenates strings; unlike `array.join`, returns `""` for an empty array.
#let concat(parts) = if parts.len() == 0 { "" } else { parts.join() }

/// Flattens nested arrays and drops `none`. A single non-array value is
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

// Content to plain text

#let _space = [ ].func()
#let _sequence = [a *b*].func()
#let _styled = {
  set text(red)
  [a]
}.func()

// Elements whose plain text is the plain text of their `body`.
#let _wrappers = (
  strong,
  emph,
  underline,
  overline,
  strike,
  highlight,
  smallcaps,
  sub,
  super,
  link,
  box,
  block,
  align,
  pad,
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
    // `text`, `raw`, symbols and shorthands like `--`
    c.text
  } else if f in _wrappers and c.has("body") {
    if type(c.body) == content { _content-to-text(c.body, field) } else { str(c.body) }
  } else {
    panic(
      "cannot convert `"
        + repr(f)
        + "` to plain text for `"
        + field
        + "`; only plain markup (text, spaces, quotes, emphasis, links, raw, …) is supported. "
        + "Pass a string instead.",
    )
  }
}

/// Converts strings, numbers, symbols and simple markup to plain text.
/// Anything without a faithful plain-text form is an error, never dropped.
#let to-text(v, field: "value") = {
  let t = type(v)
  if t == str {
    v
  } else if t in (int, float, decimal, symbol) {
    str(v)
  } else if t == content {
    _content-to-text(v, field)
  } else {
    panic("`" + field + "` must be a string or content, found " + str(t))
  }
}

/// Like `to-text`, but passes `none` through.
#let opt-text(v, field: "value") = if v == none { none } else { to-text(v, field: field) }

// Dates

#let _iso-re = regex("^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?$")

/// Turns a `datetime` or an ISO 8601 string without time zone
/// (`2026-07-01`, `2026-07-01T14:30`, `2026-07-01T14:30:00`) into a `datetime`.
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
      "`"
        + field
        + "` is not a supported date: \""
        + v
        + "\"; use `YYYY-MM-DD`, `YYYY-MM-DDTHH:MM` or `YYYY-MM-DDTHH:MM:SS` "
        + "without a time zone (set the time zone with `tz`)",
    )
  }
  let (y, mo, d, h, mi, s) = m.captures
  if h == none {
    datetime(year: int(y), month: int(mo), day: int(d))
  } else {
    datetime(
      year: int(y),
      month: int(mo),
      day: int(d),
      hour: int(h),
      minute: int(mi),
      second: if s == none { 0 } else { int(s) },
    )
  }
}

/// Like `to-datetime`, but passes `none` through.
#let opt-datetime(v, field: "date") = if v == none { none } else { to-datetime(v, field: field) }

#let has-time(dt) = dt.hour() != none

/// Fills in a missing time with midnight.
#let with-time(dt) = if has-time(dt) { dt } else {
  datetime(year: dt.year(), month: dt.month(), day: dt.day(), hour: 0, minute: 0, second: 0)
}

/// The latest of an array of datetimes (ignoring `none`), or `none`.
#let latest(dts) = {
  let dts = dts.filter(d => d != none)
  if dts.len() == 0 { return none }
  dts.sorted(key: d => with-time(d).display("[year][month][day][hour][minute][second]")).last()
}

#let _tz-re = regex("^([+-])(\d{2}):?(\d{2})$")

// Parses a time zone into `none` (UTC) or `(sign, hours, minutes)`.
#let _parse-tz(tz) = {
  if type(tz) != str {
    panic("`tz` must be a string like \"Z\", \"+01:00\" or \"-0530\", found " + str(type(tz)))
  }
  let s = tz.trim()
  if s in ("Z", "z", "UTC", "GMT") { return none }
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

/// Formats a date as an RFC 3339 timestamp, as used by Atom feeds and
/// sitemaps. Dates without a time get `00:00:00`.
///
/// ```examplec
/// rfc3339("2026-07-01T14:30", tz: "+02:00")
/// ```
///
/// -> str
#let rfc3339(
  /// The date. -> datetime | str
  dt,
  /// The time zone the date is in: `"Z"` for UTC, or an offset like
  /// `"+01:00"` or `"-0530"`. -> str
  tz: "Z",
) = {
  let dt = with-time(to-datetime(dt, field: "dt"))
  let offset = _parse-tz(tz)
  let suffix = if offset == none { "Z" } else { offset.at(0) + offset.at(1) + ":" + offset.at(2) }
  dt.display("[year]-[month]-[day]T[hour]:[minute]:[second]") + suffix
}

/// Formats a date as an RFC 2822 timestamp, as used by RSS feeds. Dates
/// without a time get `00:00:00`.
///
/// ```examplec
/// rfc2822("2026-07-01T14:30", tz: "+02:00")
/// ```
///
/// -> str
#let rfc2822(
  /// The date. -> datetime | str
  dt,
  /// The time zone the date is in: `"Z"` for UTC, or an offset like
  /// `"+01:00"` or `"-0530"`. -> str
  tz: "Z",
) = {
  let dt = with-time(to-datetime(dt, field: "dt"))
  let offset = _parse-tz(tz)
  let suffix = if offset == none { "+0000" } else { offset.join() }
  (
    dt.display("[weekday repr:short], [day] [month repr:short] [year] [hour]:[minute]:[second] ")
      + suffix
  )
}

/// W3C datetime, as used by sitemaps: dates without a time stay date-only.
#let w3c(dt, tz: "Z") = {
  let dt = to-datetime(dt, field: "lastmod")
  if has-time(dt) { rfc3339(dt, tz: tz) } else { dt.display("[year]-[month]-[day]") }
}

// Records returned by builder functions such as `atom.entry`

#let record(kind, fields) = (syndicate: kind) + fields

#let is-record(v, kind) = type(v) == dictionary and v.at("syndicate", default: none) == kind

#let expect-record(v, kind, field) = {
  if not is-record(v, kind) {
    panic("every entry of `" + field + "` must be created with `" + kind + "`, found " + repr(v))
  }
  v
}

// Document helpers

/// A `<?xml-stylesheet?>` processing instruction for `href`, or `none`.
#let stylesheet-pi(href) = {
  if href == none { return none }
  let href = to-text(href, field: "stylesheet")
  let kind = if lower(href).ends-with(".css") { "text/css" } else { "text/xsl" }
  let href = href.replace("&", "&amp;").replace("\"", "&quot;")
  (pi: "xml-stylesheet", data: "type=\"" + kind + "\" href=\"" + href + "\"")
}

/// Turns `(prefix: uri)` into `("xmlns:prefix": uri)` attributes.
#let xmlns-attrs(namespaces) = {
  let out = (:)
  for (prefix, uri) in namespaces {
    out.insert(if prefix == "" { "xmlns" } else { "xmlns:" + prefix }, uri)
  }
  out
}
