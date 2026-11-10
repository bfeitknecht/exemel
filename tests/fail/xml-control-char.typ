// error: character that is not allowed in XML
#import "/lib.typ": xml
#xml.encode((tag: "a", children: ("bell \u{7}",)))
