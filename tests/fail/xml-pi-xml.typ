// error: use the `declaration` parameter
#import "/lib.typ": xml
#xml.encode((xml.pi("xml", "version=\"1.0\""), (tag: "a")))
