ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

mklink /J "%location%\MWSE\mods\rfuzzo\gothiclockpick" "%drive%MWSE\mods\rfuzzo\gothiclockpick"

pause

