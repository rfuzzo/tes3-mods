ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravel" "%drive%MWSE\mods\rfuzzo\ImmersiveTravel"
mklink "%location%\immersive_travel-metadata.toml" "%drive%immersive_travel-metadata.toml"


pause

