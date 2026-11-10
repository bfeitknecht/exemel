// error: exactly one root element, found 2
#import "/lib.typ": xml
#xml.encode(((tag: "a"), (tag: "b")))
