$modname = "Immersive Bosmer Corpse Disposal.zip"

if (Test-Path $modname) {
    Remove-Item -Path $modname
}

Compress-Archive -Path "MWSE", "*.toml"  -DestinationPath $modname