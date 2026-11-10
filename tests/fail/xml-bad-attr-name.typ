// error: attribute name is not a valid XML name
#import "/lib.typ": xml
#xml.encode((tag: "a", attrs: ("has space": "x")))
