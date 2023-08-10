Copy-Item -PATH MWSE -Destination "_out/MWSE" -Recurse

if (Test-Path Flin.zip) {
	Remove-Item -Path Flin.zip
}
Compress-Archive -PATH _out/* -DestinationPath "Flin.zip"
Remove-Item -Path _out -Recurse