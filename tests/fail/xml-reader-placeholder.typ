// error: Typst's `xml()` reader produces these
#import "/lib.typ": xml
#xml.encode(std.xml(bytes("<r><!-- c --></r>")))
