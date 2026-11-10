// error: only comments and processing instructions may appear next to the root element
#import "/lib.typ": xml
#xml.encode(("text", (tag: "a")))
