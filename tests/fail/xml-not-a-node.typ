// error: dictionaries need a `tag` key
#import "/lib.typ": xml
#xml.encode((tag: "a", children: ((name: "b"),)))
