$modname = "ImmersiveVehicles.zip"

if (Test-Path $modname) {
	Remove-Item -Path $modname
}

Compress-Archive -Path "MWSE", "Meshes", "*.toml", "*.esp"  -DestinationPath $modname