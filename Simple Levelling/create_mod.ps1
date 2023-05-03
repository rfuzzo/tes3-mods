Copy-Item -PATH MWSE -Destination "_out/MWSE" -Recurse

Remove-Item -Path simplelevel.zip
Compress-Archive -PATH _out/* -DestinationPath "simplelevel.zip"
Remove-Item -Path _out -Recurse