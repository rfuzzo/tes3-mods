Copy-Item -PATH MWSE -Destination "_out/MWSE" -Recurse

if (Test-Path ImmersiveTravel.zip) {
	Remove-Item -Path ImmersiveTravel.zip
}
Compress-Archive -PATH _out/* -DestinationPath "ImmersiveTravel.zip"
Remove-Item -Path _out -Recurse