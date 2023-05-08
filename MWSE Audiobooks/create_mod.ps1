Copy-Item -PATH MWSE -Destination "_out/MWSE" -Recurse


Remove-Item -Path AudiobooksOfMorrowind_mwse.zip
Compress-Archive -PATH _out/* -DestinationPath "AudiobooksOfMorrowind_mwse.zip"
Remove-Item -Path _out -Recurse