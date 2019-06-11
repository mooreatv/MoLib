# MoLib
MooreaTv addons common libs

Currently consists mostly of `:Debug(optionalLevel, "some simplified format string bool=% table=%", someBool, someTable)` (unlike std format, does work for booleans and tables)

Library by default installs in the addon namespace but can also be copied to a new namespace using
`_G[addon].MoLibInstallInto(NewNamespace, shortName)`

Other functions include
- GetMyFQN : gives you Toon-Realm
- DebugEvCall : can be set as a event handler for tracing/debugging
- ...more...

See also [ChangeLog.txt](ChangeLog.txt).
