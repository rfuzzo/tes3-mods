ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

mklink /J "%location%\MWSE\mods\rfuzzo\kcdpickpocket" "%drive%MWSE\mods\rfuzzo\kcdpickpocket"
mklink "%location%\pickpocket_minigame-metadata-metadata.toml" "%drive%pickpocket_minigame-metadata-metadata.toml"


pause

