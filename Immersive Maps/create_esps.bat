ECHO off

DEL "immersive_maps_compass.esp"
mwscript deserialize immersive_maps_compass.yaml
RENAME "immersive_maps_compass.yaml.esp" "immersive_maps_compass.esp"

DEL "immersive_maps_gridmap.esp"
mwscript deserialize immersive_maps_gridmap.yaml
RENAME "immersive_maps_gridmap.yaml.esp" "immersive_maps_gridmap.esp"

DEL "immersive_maps_mel.esp"
mwscript deserialize immersive_maps_mel.yaml
RENAME "immersive_maps_mel.yaml.esp" "immersive_maps_mel.esp"
