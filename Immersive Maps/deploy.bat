ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

mklink /J "%location%\MWSE\mods\rfuzzo\ImmersiveMaps" "%drive%MWSE\mods\rfuzzo\ImmersiveMaps"

mklink "%location%\immersive_maps_compass.esp" "%drive%immersive_maps_compass.esp"
mklink "%location%\immersive_maps_gridmap.esp" "%drive%immersive_maps_gridmap.esp"
mklink "%location%\immersive_maps_mel.esp" "%drive%immersive_maps_mel.esp"

mklink "%location%\immersive_maps-metadata.toml" "%drive%immersive_maps-metadata.toml"

pause

