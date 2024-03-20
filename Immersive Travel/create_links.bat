@ECHO off

set "location=D:\games\Morrowind2\Data Files"
set "cd=%CD%"

echo %cd%

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravel" "%cd%\00 Core\MWSE\mods\rfuzzo\ImmersiveTravel"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravelEditor" "%cd%\99 Editor\MWSE\mods\rfuzzo\ImmersiveTravelEditor"

pause

