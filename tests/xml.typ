#import "/lib.typ": xml

#let enc(v, ..args) = xml.encode(v, declaration: false, ..args)

// Elements, attributes and escaped text
#assert.eq(enc((tag: "br")), "<br/>")
#assert.eq(enc((tag: "p", children: ("",))), "<p></p>")
#assert.eq(enc((tag: "p", children: ("a < b & c > d",))), "<p>a &lt; b &amp; c &gt; d</p>")
#assert.eq(
  enc((tag: "a", attrs: (href: "?a=1&b=\"2\"", title: "line\nbreak\ttab"))),
  "<a href=\"?a=1&amp;b=&quot;2&quot;\" title=\"line&#10;break&#9;tab\"/>",
)

// The function keeps the order of attributes, removes `none` and converts numbers and booleans.
#assert.eq(
  enc((tag: "x", attrs: (z: 1, a: 2.5, m: true, n: none, o: false))),
  "<x z=\"1\" a=\"2.5\" m=\"true\" o=\"false\"/>",
)

// Children: strings, numbers, nested arrays and `none`. The function ignores `none`.
#assert.eq(
  enc((tag: "p", children: ("a", none, ((tag: "b", children: ("c",)), (none,)), 42))),
  "<p>a<b>c</b>42</p>",
)
#assert.eq(enc((tag: "p", children: "single")), "<p>single</p>")

// Functions that make nodes
#assert.eq(xml.element("a", attrs: (href: "/"), "home"), (
  tag: "a",
  attrs: (href: "/"),
  children: ("home",),
))
#assert.eq(enc(xml.element("p", "x ", xml.element("em", "y"))), "<p>x <em>y</em></p>")
#assert.eq(enc(xml.element("s", xml.cdata("a]]>b"))), "<s><![CDATA[a]]]]><![CDATA[>b]]></s>")
#assert.eq(enc(xml.element("s", xml.comment(" note "))), "<s><!-- note --></s>")
#assert.eq(enc(xml.element("s", xml.raw("<b>trusted</b>"))), "<s><b>trusted</b></s>")
#assert.eq(enc(xml.element("s", xml.pi("php", "echo 1;"))), "<s><?php echo 1;?></s>")

// Prefixed names
#assert.eq(enc((tag: "atom:link", attrs: ("xml:lang": "en"))), "<atom:link xml:lang=\"en\"/>")

// The function converts content to plain text.
#assert.eq(
  enc((tag: "t", children: ([Hello *world* -- "quoted"],))),
  "<t>Hello world – \"quoted\"</t>",
)

// Declaration
#assert.eq(xml.encode((tag: "r")), "<?xml version=\"1.0\" encoding=\"UTF-8\"?><r/>")
#assert.eq(
  xml.encode((tag: "r"), declaration: "<?xml version=\"1.1\"?>"),
  "<?xml version=\"1.1\"?><r/>",
)

// With `pretty`, the function indents elements that contain only elements. It does not change text.
#assert.eq(
  enc(
    (
      tag: "root",
      children: (
        (tag: "a", children: ((tag: "b"),)),
        (tag: "p", children: ("Mixed ", (tag: "em", children: ("content",)), " stays inline")),
      ),
    ),
    pretty: true,
  ),
  "<root>\n  <a>\n    <b/>\n  </a>\n  <p>Mixed <em>content</em> stays inline</p>\n</root>\n",
)
#assert.eq(
  enc((tag: "a", children: ((tag: "b"),)), pretty: true, indent: "\t"),
  "<a>\n\t<b/>\n</a>\n",
)

// Top-level comments and processing instructions
#assert.eq(
  xml.encode(
    (xml.pi("xml-stylesheet", "href=\"s.xsl\""), xml.comment(" c "), (tag: "r")),
    pretty: true,
  ),
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<?xml-stylesheet href=\"s.xsl\"?>\n<!-- c -->\n<r/>\n",
)

// The escape function
#assert.eq(xml.escape("<&>"), "&lt;&amp;&gt;")

// Namespaces. `namespace` contains a URI, as in the output of the `xml()` reader of Typst 0.15.
#assert.eq(
  enc((
    tag: "feed",
    namespace: "http://www.w3.org/2005/Atom",
    children: (
      (tag: "title", namespace: "http://www.w3.org/2005/Atom", children: ("t",)),
      (tag: "thumb", namespace: "http://m"),
      (tag: "plain", namespace: none),
    ),
  )),
  "<feed xmlns=\"http://www.w3.org/2005/Atom\"><title>t</title><thumb xmlns=\"http://m\"/><plain xmlns=\"\"/></feed>",
)

// Decode with the reader of Typst, then encode again.
#let source = "<feed xmlns=\"http://www.w3.org/2005/Atom\"><title type=\"text\">A &amp; B</title><entry><id>1</id></entry></feed>"
#assert.eq(xml.encode(xml.decode(source), declaration: false), source)
#assert.eq(xml.decode(bytes(source)), xml.decode(source))

// The reader changes comments and processing instructions to elements with an empty tag.
// `xml.decode` removes these elements.
#assert.eq(
  xml.decode("<?xml version=\"1.0\"?><!-- top --><r><!-- c --><a/><?pi x?></r>"),
  (
    (
      namespace: none,
      tag: "r",
      attrs: (:),
      children: ((namespace: none, tag: "a", attrs: (:), children: ()),),
    ),
  ),
)

// With `path`, Typst reads files relative to the document that calls the function.
// The function keeps whitespace.
#let sample = xml.decode(path("data/sample.xml"))
#assert.eq(sample.first().tag, "catalog")
#assert.eq(xml.encode(sample), read("data/sample.xml").trim(at: end))

// For children with a namespace prefix, the result has default namespace declarations.
#assert.eq(
  xml.encode(xml.decode("<r xmlns=\"urn:a\" xmlns:b=\"urn:b\"><b:x/><y/></r>"), declaration: false),
  "<r xmlns=\"urn:a\"><x xmlns=\"urn:b\"/><y/></r>",
)

// Deep trees do not go above the call depth limit, because the serializer uses a stack.
#let deep = "x"
#for _ in range(500) { deep = (tag: "d", children: (deep,)) }
#assert.eq(xml.encode(deep, declaration: false), "<d>" * 500 + "x" + "</d>" * 500)
