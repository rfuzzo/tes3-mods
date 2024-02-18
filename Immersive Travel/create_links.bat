@ECHO off

set "location=D:\games\Morrowind2\Data Files"
set "cd=%CD%"

echo %cd%

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravel" "%cd%\00 Core\MWSE\mods\rfuzzo\ImmersiveTravel"

rem mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravelAddon" "%cd%\10 World Addon\MWSE\mods\rfuzzo\ImmersiveTravelAddon"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveVehicles" "%cd%\70 Usable Vehicles\MWSE\mods\rfuzzo\ImmersiveVehicles"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravelEditor" "%cd%\99 Editor\MWSE\mods\rfuzzo\ImmersiveTravelEditor"

pause

