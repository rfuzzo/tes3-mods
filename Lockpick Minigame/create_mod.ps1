Copy-Item -PATH MWSE -Destination "_out/MWSE" -Recurse

Remove-Item -Path LockpickMinigame.zip
Compress-Archive -PATH _out/* -DestinationPath "LockpickMinigame.zip"
Remove-Item -Path _out -Recurse