if (Test-Path ImmersiveTravel.zip) {
	Remove-Item -Path ImmersiveTravel.zip
}

Compress-Archive -Path "00 Core", "01 BCOM","02 Gnisis Docks"  -DestinationPath "ImmersiveTravel.zip"