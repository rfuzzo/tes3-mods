if (Test-Path ImmersiveVehicles.zip) {
	Remove-Item -Path ImmersiveVehicles.zip
}

Compress-Archive -Path "MWSE", "*.toml"  -DestinationPath "ImmersiveVehicles.zip"