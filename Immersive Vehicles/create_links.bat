@ECHO off

set "location=D:\games\Morrowind2\Data Files"
set "cd=%CD%"

echo %cd%

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveVehicles" "%cd%\MWSE\mods\rfuzzo\ImmersiveVehicles"

pause

