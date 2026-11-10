// error: unknown key `namespce` in element `a`
#import "/lib.typ": xml
#xml.encode((tag: "a", namespce: "x"))
