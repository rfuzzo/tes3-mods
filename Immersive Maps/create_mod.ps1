Copy-Item -PATH MWSE -Destination "_out/00 Core/MWSE" -Recurse
Copy-Item -PATH *.toml -Destination "_out/00 Core"

mkdir "_out/01 Maps and Compass Integration"
Copy-Item -PATH immersive_maps_compass.esp -Destination "_out/01 Maps and Compass Integration"

mkdir "_out/02 Gridmaps Integration"
Copy-Item -PATH immersive_maps_gridmap.esp -Destination "_out/02 Gridmaps Integration"

mkdir "_out/03 Mels Map Pack Integration"
Copy-Item -PATH immersive_maps_mel.esp -Destination "_out/03 Mels Map Pack Integration"

Remove-Item -Path ImmersiveMaps.zip
Compress-Archive -PATH _out/* -DestinationPath "ImmersiveMaps.zip"
Remove-Item -Path _out -Recurse