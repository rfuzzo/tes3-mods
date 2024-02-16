@ECHO off

set "location=C:\games\Morrowind\Data Files"
set "drive=%CD%"

echo %drive%

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravel" "%drive%\00 Core\MWSE\mods\rfuzzo\ImmersiveTravel"

rem mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravelAddon" "%drive%\10 World Addon\MWSE\mods\rfuzzo\ImmersiveTravelAddon"

mklink /J "%location%\MWSE\mods\rfuzzo\usables" "%drive%\70 Usables\MWSE\mods\rfuzzo\usables"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravelEditor" "%drive%\99 Editor\MWSE\mods\rfuzzo\ImmersiveTravelEditor"

pause

