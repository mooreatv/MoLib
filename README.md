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

Library by default installs in the addon namespace but can also be copied to a new namespace using
`_G[addon].MoLibInstallInto(NewNamespace, shortName)`

Other functions include
- Realm database
- LRU cache/table
- Hashing, rudimentary signing and random number utilities
- base62 utils
- ...more / to be updated but in meantime see the lua files...

See also [ChangeLog.txt](ChangeLog.txt).
