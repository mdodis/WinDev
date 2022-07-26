$Root = $(Resolve-Path "$PsScriptRoot\..").Path
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

function get-downloadable {
    if (-not(Test-Path -Path $args[1] -PathType Leaf)) {
        echo "Installing item: $args[0] from $args[1]"
        iwr -Uri $args[0] -OutFile $args[1]
    }
}

function ensure-dir {
    if (!(Test-Path -Path $args[0])) {
        mkdir $args[0]
    }
}

pushd $Root

# Create directories
ensure-dir ".\Bin\"
ensure-dir ".\System\"

$envCfgScript = "
@echo off
if exist env.bat del env.bat
set > environment.txt
for /f ""delims="" %%i in (environment.txt) do (echo set %%i) >> env.bat"

$shellPS1Script = @'
$devVars = Get-Content "$PsScriptRoot\\environment.txt" -Raw

## Go through the environment variables in the temp file.
## For each of them, set the variable in our local environment.
Get-Content $PsScriptRoot\environment.txt | Foreach-Object {
    if($_ -match "^(.*?)=(.*)$")
    {
        Set-Content "env:\$($matches[1])" $matches[2]
    }
}

$env:ShellHome = $(Resolve-Path "$PsScriptRoot\..\").Path

function md-reset {
    iex ". $env:ShellHome\System\Reset.ps1"
    . $PROFILE
}

$getPathNameSignature = @"
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Auto)]
public static extern uint GetLongPathName(
    string shortPath,
    StringBuilder sb,
    int bufferSize);

[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError=true)]
public static extern uint GetShortPathName(
   string longPath,
   StringBuilder shortPath,
   uint bufferSize);
"@
$getPathNameType = Add-Type -MemberDefinition $getPathNameSignature -Name GetPathNameType -UsingNamespace System.Text -PassThru


function Get-PathCanonicalCase
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        # Gets the real case of a path
        $Path
    )

    if( -not (Test-Path $Path) )
    {
        Write-Error "Path '$Path' doesn't exist."
        return
    }

    $shortBuffer = New-Object Text.StringBuilder ($Path.Length * 2)
    [void] $getPathNameType::GetShortPathName( $Path, $shortBuffer, $shortBuffer.Capacity )

    $longBuffer = New-Object Text.StringBuilder ($Path.Length * 2)
    [void] $getPathNameType::GetLongPathName( $shortBuffer.ToString(), $longBuffer, $longBuffer.Capacity )

    return $longBuffer.ToString()
}

function sudo {
    Start-Process powershell.exe -ArgumentList ("-NoExit",("cd {0}" -f (Get-Location).path)) -Verb RunAs
}

function sudo-run {
    # Start-Process powershell.exe -Verb RunAs -ArgumentList ("choco install $env:ShellHome\packages.config")
    $program = $args[0]
    Start-Process -Wait powershell.exe -Verb RunAs -ArgumentList ("-NoExit", "$program")
}

function md-choco-install-pkg {
    sudo-run "choco install -y '$env:ShellHome\packages.config'"
}

# Remove Stupid Aliases
if (Test-Path Alias:curl)   { Remove-Item Alias:curl }
if (Test-Path Alias:r)      { Remove-Item Alias:r }

function fix-docker-ports {
    net stop winnat
    net start winnat
}

function make-link {
    [CmdletBinding()]
    Param([parameter(Position=0)]$SymTarget,
          [parameter(Position=1)]$SymPath)

    New-Item -ItemType SymbolicLink -Path $SymPath -Target $SymTarget
}

function sync-folders {
    $from_folder = $args[0]
    $to_folder = $args[1]

    robocopy $from_folder $to_folder /MIR /XO /R:x /W:x
}

function touch {
    $file = $args[0]

    if ($file -eq $null) {
        throw "Error: no filename supplied"
    }

    if (Test-Path $file) {
        (Get-ChildItem $file).LastWriteTime = Get-Date
    } else {
        echo $null > $file
    }
}

function md-choco-list {
    Write-Output "<?xml version=`"1.0`" encoding=`"utf-8`"?>"
    Write-Output "<packages>"
    choco list -lo -r -y | % { "   <package id=`"$($_.SubString(0, $_.IndexOf("|")))`" version=`"$($_.SubString($_.IndexOf("|") + 1))`" />" }
    Write-Output "</packages>"
}

function md-choco-export {
    md-choco-list > $env:ShellHome\packages.config
}

Set-Alias which Where-Object

# Fix stupid python.exe in Windows conflicting with chocolatey's python
Set-Alias python "C:\Python310\python.exe"

. "$env:ShellHome\Shell.User.ps1"
'@

$shellBatchScript = '
@echo off
set CURR=%~dp0
if exist %CURR%\env.bat call %CURR%\env.bat
'

$defaultShell = '
echo "Home :: $env:ShellHome"

function Prompt {
    Write-Host -NoNewLine -ForegroundColor DarkCyan "("
    Write-Host -NoNewLine $("" + $(Get-PathCanonicalCase (Get-Location).Path | Split-Path -Leaf).substring(0))
    Write-Host -NoNewLine -ForegroundColor DarkCyan ")"
    $(Write-Host " =>" -ForegroundColor DarkCyan -NoNewLine)
    " "
}
'

# Store configuration scripts
[IO.File]::WriteAllLines("$Root\System\env-cfg.bat", $envCfgScript)
[IO.File]::WriteAllLines("$Root\System\Shell.ps1", $shellPS1Script)
[IO.File]::WriteAllLines("$Root\System\Shell.bat", $shellBatchScript)

# Create Shell.User.ps1 if not exist
if (!(Test-Path -PathType Leaf -Path "$Root\Shell.User.ps1")) {
    [IO.File]::WriteAllLines("$Root\Shell.User.ps1", $defaultShell)

}

get-downloadable "https://github.com/microsoft/vswhere/releases/latest/download/vswhere.exe" ".\System\vswhere.exe"

$vswhere = ".\System\vswhere.exe"

echo "Locating visual studio"
$vcvarsall = iex "$vswhere -nocolor -nologo -find **\vcvarsall.bat"
echo "Found $vcvarsall"


$cmdResetBatchScript = "
@echo off
cd ""$Root\System""
call ""$vcvarsall"" x86_amd64
call env-cfg.bat
"

$cmdApplyScript = "
@echo off
cd ""$Root\System""
call env-cfg.bat
"

[IO.File]::WriteAllLines("$Root\System\CmdReset.bat", $cmdResetBatchScript)
[IO.File]::WriteAllLines("$Root\System\CmdApply.bat", $cmdApplyScript)

start -Wait -FilePath "$env:comspec" -ArgumentList "$env:comspec /c ""$Root\System\CmdReset.bat"""
popd

$cmdlineApply = "cmd /c $Root\System\CmdApply.bat"

start -Wait -FilePath "powershell.exe" -ArgumentList "$cmdlineApply"

. $PROFILE