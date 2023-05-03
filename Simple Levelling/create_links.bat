ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

mklink /J "%location%\MWSE\mods\rfuzzo\simplelevel" "%drive%MWSE\mods\rfuzzo\simplelevel"

pause

