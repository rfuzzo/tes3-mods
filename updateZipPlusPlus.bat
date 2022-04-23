@echo off

echo building exe
set OLDDIR=%CD%
cd E:\source\repos\ZipPlusPlus
dotnet publish ZipPlusPlus.sln -o publish -c Release -r win-x64 -p:PublishSingleFile=true --self-contained false

echo copy exe to %OLDDIR%
robocopy publish "%OLDDIR%" ZipPlusPlus.exe /E /IM /IS /IT

echo %ERRORLEVEL%
IF %ERRORLEVEL% NEQ 3 pause