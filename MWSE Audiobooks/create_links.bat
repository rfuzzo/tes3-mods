ECHO off

set "location=E:\gog\Morrowind2\Data Files"
set "drive=%~d0"

mklink /J "%location%\MWSE\mods\rfuzzo\Audiobooks" "%drive%MWSE\mods\rfuzzo\Audiobooks"
mklink "%location%\audiobooks-metadata.toml" "%drive%audiobooks-metadata.toml"


pause

