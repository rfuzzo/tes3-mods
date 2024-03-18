# delete folder "build" if it exists
if (Test-Path "build") {
    Remove-Item -Recurse -Force "build"
}
 
# mkdir build if it does not exist
if (-not (Test-Path "build")) {
    New-Item -ItemType Directory -Path "build"
}


# iterate through all folders in the current directory and chck if a file called "create_mods.ps1" exists if it does, execute it
Get-ChildItem -Directory | ForEach-Object {
    $scriptPath = Join-Path $_.FullName "create_mod.ps1"
    if (Test-Path $scriptPath) {
        # display the path of the script
        Write-Host $scriptPath
        # cd into the folder
        Set-Location $_.FullName
        # execute the script
        & $scriptPath
        # move all *.zip files to the fold ..\build
        Get-ChildItem $_.FullName -Filter *.zip | Move-Item -Destination "..\build"
        # cd back to the root folder
        Set-Location ..
    }
}

