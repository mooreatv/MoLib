# MoLib
MooreaTv addons common libs

2 Files/set of utilities:

- General and debugging functions, like
`:Debug(optionalLevel, "some simplified format string bool=% table=%", someBool, someTable)`
(unlike std format, does work for booleans and tables)

- UI widget library
Both extensively used by DynamicBoxer e.g.
https://github.com/mooreatv/DynamicBoxer/blob/master/DynamicBoxer/DBoxUI.lua
but also meant to be reused in other addons, not just mine.

It now also includes Pixel Perfect drawing support as demonstrated in
https://github.com/mooreatv/PixelPerfectAlign

Library by default installs in the addon namespace but can also be copied to a new namespace using
`_G[addon].MoLibInstallInto(NewNamespace, shortName)`

Other functions include
- Realm database
- LRU cache/table
- Hashing, rudimentary signing and random number utilities
- base62 utils
- binary to baseN where N is any between 2 and 255 (most useful values being 91(printable withou space),92(with space),123(valid chat characters) and 255)
  which allows you to transmit binary (compressed) data with guaranteed minimal text size
- ...more / to be updated but in meantime see the lua files...

See also [ChangeLog.txt](ChangeLog.txt).

MoLib library sources are at https://github.com/mooreatv/MoLib
