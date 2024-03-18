$modname = "loading_tooltips_mwse.zip"

if (Test-Path $modname) {
    Remove-Item -Path $modname
}

Compress-Archive -Path "MWSE", "*.toml"  -DestinationPath $modname