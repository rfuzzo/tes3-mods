$modname = "Flin.zip"

if (Test-Path $modname) {
	Remove-Item -Path $modname
}

Compress-Archive -Path "MWSE", "icons", "meshes", "textures", "*.esp", "*.toml"  -DestinationPath $modname

function Convert-MarkdownToBBCode {
    param (
        [string]$markdownText
    )

    # Convert ### to size 3 and bold
    $markdownText = $markdownText -replace '### (.*)', '[size=3][b]$1[/b][/size]'

    # Convert ## to size 4
    $markdownText = $markdownText -replace '## (.*)', '[size=4]$1[/size]'

    # Convert # to size 5
    $markdownText = $markdownText -replace '# (.*)', '[size=5]$1[/size]'

    # Convert URLs
    $markdownText = $markdownText -replace '\[([^\]]+)\]\(([^)]+)\)', '[url=$2]$1[/url]'

    return $markdownText
}

# read the file README.md
$markdownExample = Get-Content README.md -Raw

# convert the markdown to BBCode
$bbcodeOutput = Convert-MarkdownToBBCode -markdownText $markdownExample

# write the BBCode to a file called README.bbcode
Set-Content -Path README.bbcode -Value $bbcodeOutput
