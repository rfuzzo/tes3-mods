Copy-Item -PATH MWSE -Destination "_out/MWSE" -Recurse
Copy-Item -PATH immersivetravel.esp -Destination "_out"

if (Test-Path ImmersiveTravel.zip) {
	Remove-Item -Path ImmersiveTravel.zip
}
Compress-Archive -PATH _out/* -DestinationPath "ImmersiveTravel.zip"
Remove-Item -Path _out -Recurse