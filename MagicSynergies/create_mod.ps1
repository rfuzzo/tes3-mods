Copy-Item -PATH MWSE -Destination "_out/MWSE" -Recurse

if (Test-Path MagicSynergies.zip) {
	Remove-Item -Path MagicSynergies.zip
}
Compress-Archive -PATH _out/* -DestinationPath "MagicSynergies.zip"
Remove-Item -Path _out -Recurse