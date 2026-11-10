// XML serialization.
//
// syndicate is a fork of exemel by Jeremy Gao (https://github.com/wensimehrp/exemel),
// licensed under Apache-2.0. This file replaces the original Rust/WASM serializer.

#import "util.typ" as _util

#let _name-re = regex("^[\p{L}_:][\p{L}\p{N}_:.\-\x{B7}]*$")
#let _invalid-re = regex("[\x00-\x08\x0B\x0C\x0E-\x1F\x{FFFE}\x{FFFF}]")

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

/// Escape a string for use as XML character data.
#let escape(s) = {
  _check-chars(_util.to-text(s, field: "text"), "text").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
}

#let _escape-attr(s) = {
  escape(s).replace("\"", "&quot;").replace("\t", "&#9;").replace("\n", "&#10;").replace("\r", "&#13;")
}

/// Build an element node: `xml.element("a", attrs: (href: "/"), "link text")`.
/// Equivalent to the dictionary `(tag: "a", attrs: (href: "/"), children: ("link text",))`.
#let element(tag, attrs: (:), ..children) = {
  if children.named().len() > 0 {
    panic("unexpected named arguments " + repr(children.named().keys()) + "; put attributes into `attrs`")
  }
  (tag: tag, attrs: attrs, children: children.pos())
}

/// A comment node: `<!-- body -->`.
#let comment(body) = (comment: body)

/// A CDATA section: `<![CDATA[body]]>`.
#let cdata(body) = (cdata: body)

/// A processing instruction: `<?target data?>`.
#let pi(target, data) = (pi: target, data: data)

/// Pre-serialized markup that is written verbatim. You are responsible for
/// it being well-formed.
#let raw(body) = (raw: body)

#let _element-keys = ("tag", "attrs", "children", "namespace")

#let _kind(node) = {
  let t = type(node)
  if t == str or t == content or t == int or t == float or t == decimal or t == symbol {
    return "text"
  }
  if t != dictionary {
    panic("not an XML node: " + repr(node) + " (expected a string or a dictionary)")
  }
  if "tag" in node {
    if node.tag == "" {
      panic("element with an empty tag; Typst's `xml()` reader produces these for comments and processing instructions, read files with `xml.decode` instead, which removes them")
    }
    for k in node.keys() {
      if k not in _element-keys {
        panic("unknown key `" + k + "` in element `" + str(node.tag) + "`; allowed are " + _element-keys.map(k => "`" + k + "`").join(", "))
      }
    }
    return "element"
  }
  for k in ("comment", "cdata", "pi", "raw") {
    if k in node { return k }
  }
  panic("not an XML node: " + repr(node) + " (dictionaries need a `tag` key)")
}

#let _attr-value(v, name) = {
  let t = type(v)
  if t == bool { if v { "true" } else { "false" } } else { _util.to-text(v, field: "attribute `" + name + "`") }
}

// Serialize a non-element node.
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
  // processing instruction
  let target = _check-name(node.pi, "processing instruction target")
  if lower(target) == "xml" {
    panic("use the `declaration` parameter of `xml.encode` for the XML declaration")
  }
  let data = node.at("data", default: none)
  let data = if data == none { "" } else { _check-chars(_util.to-text(data, field: "processing instruction"), "processing instruction") }
  if data.contains("?>") {
    panic("processing instructions must not contain `?>`: " + repr(data))
  }
  let data = if data == "" { "" } else { " " + data }
  "<?" + target + data + "?>"
}

// The start tag (without the closing `>` or `/>`) and the default namespace in scope.
#let _start-tag(node, tag, default-ns) = {
  let attrs = node.at("attrs", default: (:))
  if type(attrs) != dictionary {
    panic("`attrs` of element `" + tag + "` must be a dictionary, found " + str(type(attrs)))
  }
  // Typst's own `xml()` reader (0.15+) records each element's namespace URI;
  // re-declare it as default namespace wherever it changes so round-trips are lossless.
  let ns = default-ns
  let parts = ()
  if "xmlns" in attrs {
    ns = attrs.xmlns
  } else if "namespace" in node and not tag.contains(":") and node.namespace != default-ns {
    ns = node.namespace
    parts.push(" xmlns=\"" + _escape-attr(if ns == none { "" } else { ns }) + "\"")
  }
  for (k, v) in attrs {
    if v == none { continue }
    parts.push(" " + _check-name(k, "attribute name") + "=\"" + _escape-attr(_attr-value(v, k)) + "\"")
  }
  ("<" + tag + _util.concat(parts), ns)
}

// Iterative (stack-based) so that deeply nested trees don't hit Typst's call depth limit.
// The stack holds output strings and `(node, depth, default-ns, pretty)` tasks.
#let _render(root, pretty, pad) = {
  let out = ()
  let stack = ((root, 0, none, pretty),)
  // Typst stops `while` loops after 10 000 iterations, so tasks are processed in
  // batches by a bounded inner `for` loop.
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
      // Only indent element-only content: inserting whitespace next to text would change it.
      let mixed = children.any(c => _kind(c) in ("text", "cdata", "raw"))
      let tasks = ()
      if pretty and not mixed {
        let indent = "\n" + pad * (depth + 1)
        for c in children {
          tasks.push(indent)
          tasks.push((c, depth + 1, ns, true))
        }
        tasks.push("\n" + pad * depth + "</" + tag + ">")
      } else {
        for c in children {
          tasks.push((c, depth + 1, ns, false))
        }
        tasks.push("</" + tag + ">")
      }
      stack += tasks.rev()
    }
  }
  _util.concat(out)
}

// Typst's `xml()` reader turns comments and processing instructions into
// elements with an empty tag. Rebuild the tree without them (iteratively, so
// deep documents don't hit the call depth limit).
#let _strip-placeholders(nodes) = {
  let is-placeholder(n) = type(n) == dictionary and n.at("tag", default: none) == ""
  // Frames: the element being rebuilt (`none` for the top level), its finished
  // children and its remaining children (reversed, so `pop` yields the next one).
  let stack = ((node: none, done: (), todo: nodes.rev()),)
  while true {
    for _ in range(4096) {
      if stack.at(-1).todo.len() == 0 {
        let frame = stack.pop()
        let finished = if frame.node == none { frame.done } else { frame.node + (children: frame.done) }
        if stack.len() == 0 { return finished }
        stack.at(-1).done.push(finished)
        continue
      }
      let child = stack.at(-1).todo.pop()
      if is-placeholder(child) { continue }
      if type(child) == dictionary and "children" in child {
        stack.push((node: child, done: (), todo: child.children.rev()))
      } else {
        stack.at(-1).done.push(child)
      }
    }
  }
}

/// Parse XML into the node structure used by `xml.encode`, using Typst's
/// built-in `xml()` reader.
///
/// - `source`: the XML as a string or bytes, or a `path(..)` to a file. Use
///   `path` rather than a plain string for files, so that the file is found
///   relative to your document instead of this package.
///
/// Returns an array of top-level nodes. Elements are
/// `(namespace: .., tag: .., attrs: .., children: ..)`, text is a string.
/// Comments and processing instructions are dropped, and namespace prefixes
/// are replaced by the `namespace` URI (a limitation of the reader).
#let decode(source) = {
  let data = if type(source) == str { bytes(source) } else { source }
  _strip-placeholders(std.xml(data))
}

/// Serialize an XML tree to a string.
///
/// - `root`: an element, or an array of top-level nodes (comments and
///   processing instructions around exactly one element).
/// - `pretty`: indent element-only content. Text content is never altered.
/// - `indent`: number of spaces (or a string) per level when `pretty` is set.
/// - `declaration`: `true` for `<?xml version="1.0" encoding="UTF-8"?>`,
///   `false` for none, or a custom string.
#let encode(root, pretty: false, indent: 2, declaration: true) = {
  // Whitespace between top-level nodes (as returned by Typst's `xml()` reader) is insignificant.
  let nodes = _util.flatten(root).filter(n => not (type(n) == str and n.trim() == ""))
  let kinds = nodes.map(_kind)
  if kinds.filter(k => k == "element").len() != 1 {
    panic("an XML document needs exactly one root element, found " + str(kinds.filter(k => k == "element").len()))
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
  for n in nodes {
    parts.push(_render(n, pretty, pad))
  }
  if pretty { parts.join("\n") + "\n" } else { parts.join() }
}
