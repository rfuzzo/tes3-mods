ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveMaps" "%drive%MWSE\mods\rfuzzo\ImmersiveMaps"

rem mklink "%location%\immersive_maps_compass.esp" "%drive%immersive_maps_compass.esp"
rem mklink "%location%\immersive_maps_gridmap.esp" "%drive%immersive_maps_gridmap.esp"
rem mklink "%location%\immersive_maps_mel.esp" "%drive%immersive_maps_mel.esp"

xcopy /Y immersive_maps_compass.esp "%location%\immersive_maps_compass.esp"
xcopy /Y immersive_maps_gridmap.esp "%location%\immersive_maps_gridmap.esp"
xcopy /Y immersive_maps_mel.esp "%location%\immersive_maps_mel.esp"

mklink "%location%\immersive_maps-metadata.toml" "%drive%immersive_maps-metadata.toml"
rem xcopy /Y immersive_maps-metadata.toml "%location%\immersive_maps-metadata.toml"

pause

