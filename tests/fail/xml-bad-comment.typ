// error: must not contain `--`
#import "/lib.typ": xml
#xml.encode(xml.element("a", xml.comment("a -- b")))
