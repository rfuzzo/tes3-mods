@ECHO off

set "modname=Flin"

rem get the environment variable with name TES3PATH
set "datafiles=%TES3PATH%\Data Files"
set "cd=%CD%"

echo cd: %cd%
echo gamepath: %datafiles%
mklink /J "%datafiles%\MWSE\mods\%modname%" "%cd%\MWSE\mods\%modname%"

echo mo2mods: %MO2MODS%
mklink /J "%MO2MODS%\%modname%" "%cd%"


pause

