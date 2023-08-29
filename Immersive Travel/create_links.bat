ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

echo %drive%

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravel" "%drive%00 Core\MWSE\mods\rfuzzo\ImmersiveTravel"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravelAddon" "%drive%10 World Addon\MWSE\mods\rfuzzo\ImmersiveTravelAddon"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravelEditor" "%drive%99 Editor\MWSE\mods\rfuzzo\ImmersiveTravelEditor"

pause

