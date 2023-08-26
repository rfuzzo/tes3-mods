ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

echo %drive%

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveTravel" "%drive%00 Core\MWSE\mods\rfuzzo\ImmersiveTravel"

pause

