// XML encoding and decoding.
//
// Part of syndicate, a fork of exemel by Jeremy Gao.
// Licensed under the Apache License 2.0; see LICENSE and NOTICE.

#import "util.typ" as _util

#let _name-re = regex("^[\p{L}_:][\p{L}\p{N}_:.\-\x{B7}]*$")
#let _invalid-re = regex("[\x00-\x08\x0B\x0C\x0E-\x1F\x{FFFE}\x{FFFF}]")
#let _element-keys = ("tag", "attrs", "children", "namespace")

#let _check-chars(s, what) = {
  if s.contains(_invalid-re) {
    panic(what + " contains a character that is not allowed in XML: " + repr(s))
  }
  s
}

#let _check-name(name, what) = {
  if type(name) != str or name.match(_name-re) == none {
    panic(what + " is not a valid XML name: " + repr(name))
  }
  name
}

/// Escapes text for use as XML character data: `&`, `<` and `>` become
/// entity references.
///
/// ```examplec
/// xml.escape("Fish & <Chips>")
/// ```
///
/// -> str
#let escape(
  /// The text. -> str | content
  text,
) = {
  _check-chars(_util.to-text(text, field: "text"), "text")
    .replace("&", "&amp;")
    .replace("<", "&lt;")
    .replace(">", "&gt;")
}

#let _escape-attr(s) = {
  escape(s)
    .replace("\"", "&quot;")
    .replace("\t", "&#9;")
    .replace("\n", "&#10;")
    .replace("\r", "&#13;")
}

/// Builds an element node. Equivalent to writing the dictionary
/// `(tag: tag, attrs: attrs, children: children)` yourself.
///
/// ```examplec
/// xml.element("a", attrs: (href: "/"), "Home")
/// ```
///
/// -> dictionary
#let element(
  /// The element name, optionally with a namespace prefix like `"atom:link"`. -> str
  tag,
  /// The attributes. Attributes set to `none` are omitted. -> dictionary
  attrs: (:),
  /// The child nodes. -> str | content | dictionary | array | none
  ..children,
) = {
  if children.named().len() > 0 {
    panic(
      "unexpected named arguments "
        + repr(children.named().keys())
        + "; put attributes into `attrs`",
    )
  }
  (tag: tag, attrs: attrs, children: children.pos())
}

/// A comment node, written as `<!--body-->`.
///
/// ```examplec
/// xml.encode(
///   (tag: "p", children: (xml.comment(" draft "),)),
///   declaration: false,
/// )
/// ```
///
/// -> dictionary
#let comment(
  /// The comment text. It must not contain `--` or end with `-`. -> str
  body,
) = (comment: body)

/// A CDATA section, written as `<![CDATA[body]]>`. Occurrences of `]]>` are
/// split across two sections, so any text is safe.
///
/// ```examplec
/// xml.encode(
///   (tag: "script", children: (xml.cdata("if (a < b) go()"),)),
///   declaration: false,
/// )
/// ```
///
/// -> dictionary
#let cdata(
  /// The text. -> str
  body,
) = (cdata: body)

/// A processing instruction, written as `<?target data?>`.
///
/// ```examplec
/// xml.encode(
///   (xml.pi("xml-stylesheet", "href=\"style.xsl\""), (tag: "doc")),
///   declaration: false,
/// )
/// ```
///
/// -> dictionary
#let pi(
  /// The target, e.g. `"xml-stylesheet"`. -> str
  target,
  /// The instruction's data. It must not contain `?>`. -> str | none
  data,
) = (pi: target, data: data)

/// Pre-serialized markup, written verbatim. You are responsible for it being
/// well-formed.
///
/// ```examplec
/// xml.encode(
///   (tag: "p", children: (xml.raw("<b>bold</b> &amp; raw"),)),
///   declaration: false,
/// )
/// ```
///
/// -> dictionary
#let raw(
  /// The markup. -> str
  body,
) = (raw: body)

// The kind of a node: "text", "element", "comment", "cdata", "pi" or "raw".
#let _kind(node) = {
  let t = type(node)
  if t in (str, content, int, float, decimal, symbol) {
    return "text"
  }
  if t != dictionary {
    panic("not an XML node: " + repr(node) + " (expected a string or a dictionary)")
  }
  if "tag" in node {
    if node.tag == "" {
      panic(
        "element with an empty tag; Typst's `xml()` reader produces these for comments and "
          + "processing instructions, read files with `xml.decode` instead, which removes them",
      )
    }
    for key in node.keys() {
      if key not in _element-keys {
        panic(
          "unknown key `"
            + key
            + "` in element `"
            + str(node.tag)
            + "`; allowed are "
            + _element-keys.map(k => "`" + k + "`").join(", "),
        )
      }
    }
    return "element"
  }
  for kind in ("comment", "cdata", "pi", "raw") {
    if kind in node { return kind }
  }
  panic("not an XML node: " + repr(node) + " (dictionaries need a `tag` key)")
}

#let _render-leaf(node, kind) = {
  if kind == "text" {
    return escape(_util.to-text(node, field: "text node"))
  }
  if kind == "raw" {
    return _check-chars(_util.to-text(node.raw, field: "raw"), "raw markup")
  }
  if kind == "cdata" {
    let body = _check-chars(_util.to-text(node.cdata, field: "cdata"), "CDATA section")
    return "<![CDATA[" + body.replace("]]>", "]]]]><![CDATA[>") + "]]>"
  }
  if kind == "comment" {
    let body = _check-chars(_util.to-text(node.comment, field: "comment"), "comment")
    if body.contains("--") or body.ends-with("-") {
      panic("XML comments must not contain `--` or end with `-`: " + repr(body))
    }
    return "<!--" + body + "-->"
  }
  // Processing instruction
  let target = _check-name(node.pi, "processing instruction target")
  if lower(target) == "xml" {
    panic("use the `declaration` parameter of `xml.encode` for the XML declaration")
  }
  let data = _util.opt-text(node.at("data", default: none), field: "processing instruction")
  let data = if data == none { "" } else { _check-chars(data, "processing instruction") }
  if data.contains("?>") {
    panic("processing instructions must not contain `?>`: " + repr(data))
  }
  "<?" + target + (if data == "" { "" } else { " " + data }) + "?>"
}

// Returns the start tag without its closing `>` or `/>`, and the default
// namespace in scope for the element's children.
#let _start-tag(node, tag, default-ns) = {
  let attrs = node.at("attrs", default: (:))
  if type(attrs) != dictionary {
    panic("`attrs` of element `" + tag + "` must be a dictionary, found " + str(type(attrs)))
  }
  // Decoded elements carry their namespace URI. Declare it as the default
  // namespace wherever it changes, so namespaced documents round-trip.
  let ns = default-ns
  let parts = ()
  if "xmlns" in attrs {
    ns = attrs.xmlns
  } else if "namespace" in node and not tag.contains(":") and node.namespace != default-ns {
    ns = node.namespace
    parts.push(" xmlns=\"" + _escape-attr(if ns == none { "" } else { ns }) + "\"")
  }
  for (name, value) in attrs {
    if value == none { continue }
    let value = if type(value) == bool {
      if value { "true" } else { "false" }
    } else {
      _util.to-text(value, field: "attribute `" + name + "`")
    }
    parts.push(" " + _check-name(name, "attribute name") + "=\"" + _escape-attr(value) + "\"")
  }
  ("<" + tag + _util.concat(parts), ns)
}

// Serializes a node. Works with an explicit stack instead of recursion, so
// deep trees don't hit Typst's call depth limit. The stack holds output
// strings and `(node, depth, default-ns, pretty)` tasks.
#let _render(root, pretty, pad) = {
  let out = ()
  let stack = ((root, 0, none, pretty),)
  // Typst stops `while` loops after 10 000 iterations, so work in batches.
  while stack.len() > 0 {
    for _ in range(4096) {
      if stack.len() == 0 { break }
      let task = stack.pop()
      if type(task) == str {
        out.push(task)
        continue
      }
      let (node, depth, default-ns, pretty) = task
      let kind = _kind(node)
      if kind != "element" {
        out.push(_render-leaf(node, kind))
        continue
      }
      let tag = _check-name(node.tag, "tag")
      let (open, ns) = _start-tag(node, tag, default-ns)
      let children = _util.flatten(node.at("children", default: ()))
      if children.len() == 0 {
        out.push(open + "/>")
        continue
      }
      out.push(open + ">")
      // Only indent element-only content: whitespace next to text would change it.
      let mixed = children.any(c => _kind(c) in ("text", "cdata", "raw"))
      let tasks = ()
      if pretty and not mixed {
        let indent = "\n" + pad * (depth + 1)
        for child in children {
          tasks.push(indent)
          tasks.push((child, depth + 1, ns, true))
        }
        tasks.push("\n" + pad * depth + "</" + tag + ">")
      } else {
        for child in children {
          tasks.push((child, depth + 1, ns, false))
        }
        tasks.push("</" + tag + ">")
      }
      stack += tasks.rev()
    }
  }
  _util.concat(out)
}

/// Serializes a tree of nodes to an XML document.
///
/// Elements are dictionaries `(tag: .., attrs: .., children: ..)`, where
/// `attrs` and `children` are optional. Text is given as strings, numbers or
/// simple content and is escaped automatically. Children set to `none` are
/// skipped and nested arrays are flattened, so `if` and `.map(..)` can be
/// used inline.
///
/// ```examplec
/// xml.encode(
///   (
///     tag: "book",
///     attrs: (id: "bk101", lang: none),
///     children: (
///       (tag: "title", children: ("XML & Typst",)),
///       (tag: "price", children: (44.95,)),
///     ),
///   ),
///   pretty: true,
/// )
/// ```
///
/// -> str
#let encode(
  /// The root element, or an array of top-level nodes: exactly one element,
  /// optionally surrounded by comments and processing instructions.
  /// -> dictionary | array
  root,
  /// Whether to indent elements that contain only other elements. Text
  /// content is never altered. -> bool
  pretty: false,
  /// The indentation per level when `pretty` is set: a number of spaces, or a
  /// string such as `"\t"`. -> int | str
  indent: 2,
  /// `true` for `<?xml version="1.0" encoding="UTF-8"?>`, `false` for no
  /// declaration, or a custom declaration. -> bool | str
  declaration: true,
) = {
  // Whitespace between top-level nodes (as returned by the reader) is insignificant.
  let nodes = _util.flatten(root).filter(n => not (type(n) == str and n.trim() == ""))
  let kinds = nodes.map(_kind)
  let elements = kinds.filter(k => k == "element").len()
  if elements != 1 {
    panic("an XML document needs exactly one root element, found " + str(elements))
  }
  if kinds.any(k => k not in ("element", "comment", "pi")) {
    panic("only comments and processing instructions may appear next to the root element")
  }
  let pad = if type(indent) == int { " " * indent } else { indent }
  let parts = ()
  if declaration == true {
    parts.push("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
  } else if type(declaration) == str {
    parts.push(declaration)
  }
  for node in nodes {
    parts.push(_render(node, pretty, pad))
  }
  if pretty { parts.join("\n") + "\n" } else { parts.join() }
}

// Rebuilds the reader's output without the empty-tag placeholders it produces
// for comments and processing instructions. Iterative, like `_render`. Each
// frame holds the element being rebuilt (`none` at the top level), its
// finished children and its remaining children in reverse order.
#let _strip-placeholders(nodes) = {
  let stack = ((node: none, done: (), todo: nodes.rev()),)
  while true {
    for _ in range(4096) {
      if stack.at(-1).todo.len() == 0 {
        let frame = stack.pop()
        let finished = if frame.node == none { frame.done } else {
          frame.node + (children: frame.done)
        }
        if stack.len() == 0 { return finished }
        stack.at(-1).done.push(finished)
        continue
      }
      let child = stack.at(-1).todo.pop()
      if type(child) == dictionary and child.at("tag", default: none) == "" { continue }
      if type(child) == dictionary and "children" in child {
        stack.push((node: child, done: (), todo: child.children.rev()))
      } else {
        stack.at(-1).done.push(child)
      }
    }
  }
}

/// Parses XML into the node structure used by `xml.encode`, using Typst's
/// built-in reader.
///
/// Elements are returned as `(namespace: .., tag: .., attrs: .., children: ..)`,
/// where `namespace` is the element's namespace URI, which `xml.encode` turns
/// back into `xmlns` declarations. The reader drops comments, processing
/// instructions and namespace prefixes.
///
/// ```examplec
/// xml.decode("<p>Hello <b>world</b></p>")
/// ```
///
/// -> array
#let decode(
  /// The XML as a string or bytes, or a `path(..)` to a file. Use `path`
  /// rather than a plain file name, so that the file is found relative to
  /// your document instead of this package. -> str | bytes | path
  source,
) = {
  let data = if type(source) == str { bytes(source) } else { source }
  _strip-placeholders(std.xml(data))
}
