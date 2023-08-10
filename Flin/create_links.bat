ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

mklink /J "%location%\MWSE\mods\rfuzzo\Flin" "%drive%MWSE\mods\rfuzzo\Flin"

pause

