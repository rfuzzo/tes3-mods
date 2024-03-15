@ECHO off

set "location=D:\games\Morrowind2\Data Files"
set "cd=%CD%"

echo %cd%

mklink /J "%location%\MWSE\mods\MagicSynergies" "%cd%\MWSE\mods\MagicSynergies"

pause

