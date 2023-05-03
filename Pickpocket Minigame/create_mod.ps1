Copy-Item -PATH MWSE -Destination "_out/MWSE" -Recurse

Remove-Item -Path PickpocketMinigame.zip
Compress-Archive -PATH _out/* -DestinationPath "PickpocketMinigame.zip"
Remove-Item -Path _out -Recurse