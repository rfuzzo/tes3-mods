$modname = "Flin.zip"

if (Test-Path $modname) {
	Remove-Item -Path $modname
}

Compress-Archive -Path "MWSE", "icons", "meshes", "textures", "*.esp", "*.toml"  -DestinationPath $modname