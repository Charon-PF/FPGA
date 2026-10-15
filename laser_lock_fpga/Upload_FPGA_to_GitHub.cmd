@echo off
setlocal EnableExtensions
chcp 65001 >nul
set "UPLOADER_SELF=%~f0"
set "UPLOADER_SOURCE=%~dp0"
set "UPLOADER_PS=%TEMP%\FPGA_GitHub_Upload_%RANDOM%_%RANDOM%.ps1"
title FPGA - GitHub One-Click Upload

echo ======================================================
echo   FPGA Vivado project - One-click GitHub upload
echo   Repository: https://github.com/Charon-PF/FPGA
echo ======================================================
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: Windows PowerShell is not available.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$v = Get-Content -LiteralPath $env:UPLOADER_SELF; $i = [Array]::IndexOf($v, '#__POWERSHELL_BEGIN__'); if ($i -lt 0) { exit 2 }; [System.IO.File]::WriteAllLines($env:UPLOADER_PS, [string[]]$v[($i + 1)..($v.Length - 1)], ([System.Text.UTF8Encoding]::new($true)))"
if errorlevel 1 (
  echo ERROR: Cannot prepare the upload program.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%UPLOADER_PS%"
set "RESULT=%ERRORLEVEL%"
del /q "%UPLOADER_PS%" >nul 2>nul
echo.
if "%RESULT%"=="0" (
  echo SUCCESS. Your Vivado project is now on GitHub.
) else (
  echo UPLOAD NOT COMPLETED. Read the error details above.
)
echo.
pause
exit /b %RESULT%

#__POWERSHELL_BEGIN__
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Repository = 'https://github.com/Charon-PF/FPGA.git'
$RepositoryPage = 'https://github.com/Charon-PF/FPGA'
$Branch = 'main'
$SourceDirectory = [System.IO.Path]::GetFullPath($env:UPLOADER_SOURCE).TrimEnd('\', '/')
$ProjectName = Split-Path -Path $SourceDirectory -Leaf
$TempRepository = Join-Path $env:TEMP ('FPGA_GitHub_' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$UploadSucceeded = $false

function Step([string] $message) {
    Write-Host ''
    Write-Host ('==> ' + $message) -ForegroundColor Cyan
}

function Invoke-Git([string[]] $Arguments) {
    & $script:GitPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ('Git command failed (exit ' + $LASTEXITCODE + '): git ' + ($Arguments -join ' '))
    }
}

function Find-Git {
    $c = Get-Command git.exe -ErrorAction SilentlyContinue
    if ($null -ne $c) { return $c.Source }
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe'),
        (Join-Path $env:ProgramFiles 'Git\cmd\git.exe'),
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files (x86)\Git\cmd\git.exe'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

try {
    Step 'Checking the Vivado project'
    if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
        throw 'Project folder was not found.'
    }
    $xprFiles = @(Get-ChildItem -LiteralPath $SourceDirectory -Filter '*.xpr' -File)
    if ($xprFiles.Count -eq 0) {
        throw 'No .xpr file found here. Put this .cmd file beside your Vivado .xpr project file and double-click it.'
    }
    Write-Host ('Project: ' + $ProjectName)
    Write-Host ('Vivado file: ' + $xprFiles[0].Name)

    Step 'Checking Git for Windows'
    $script:GitPath = Find-Git
    if (-not $script:GitPath) {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $winget) {
            throw 'Git is not installed. Please install Git for Windows from https://git-scm.com/downloads/win and run this file again.'
        }
        Write-Host 'Git is missing. Attempting automatic installation with Windows Package Manager...'
        & $winget.Source install --id Git.Git --exact --source winget --scope user --silent --accept-package-agreements --accept-source-agreements
        $script:GitPath = Find-Git
        if (-not $script:GitPath) {
            Write-Host 'Retrying installation without the user-scope setting...'
            & $winget.Source install --id Git.Git --exact --source winget --silent --accept-package-agreements --accept-source-agreements
            $script:GitPath = Find-Git
        }
        if (-not $script:GitPath) {
            throw 'Git installation was not detected. Install Git for Windows, then double-click this file again.'
        }
    }
    & $script:GitPath --version
    if ($LASTEXITCODE -ne 0) { throw 'Git could not start.' }

    Step 'Downloading the GitHub repository'
    Write-Host 'If a GitHub login window appears, sign in and approve access.' -ForegroundColor Yellow
    Invoke-Git -Arguments @('-c', 'core.longpaths=true', 'clone', $Repository, $TempRepository)
    Invoke-Git -Arguments @('-C', $TempRepository, 'config', 'core.longpaths', 'true')

    # Work on main even when the repository is initially empty.
    & $script:GitPath -C $TempRepository show-ref --verify --quiet 'refs/remotes/origin/main'
    $hasRemoteMain = ($LASTEXITCODE -eq 0)
    if ($hasRemoteMain) {
        Invoke-Git -Arguments @('-C', $TempRepository, 'checkout', '-B', $Branch, 'origin/main')
    } else {
        $localBranches = @(& $script:GitPath -C $TempRepository branch --format='%(refname:short)')
        if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Git branches.' }
        $hasCommit = ($localBranches.Count -gt 0)
        if ($hasCommit) {
            Invoke-Git -Arguments @('-C', $TempRepository, 'checkout', '-B', $Branch)
        } else {
            Invoke-Git -Arguments @('-C', $TempRepository, 'symbolic-ref', 'HEAD', 'refs/heads/main')
        }
    }

    Step 'Copying source code and essential Vivado project files'
    $Destination = Join-Path $TempRepository $ProjectName
    New-Item -Path $Destination -ItemType Directory -Force | Out-Null

    # Skip auto-generated Vivado folders. Keep .srcs, RTL, constraints, IP .xci, BD .bd, TCL, README, etc.
    $ExcludeDirs = @(
        '.git', '.Xil', '*.cache', '*.runs', '*.sim', '*.gen', '*.hw',
        '*.ip_user_files', 'node_modules', '__pycache__', '.venv', '.vs'
    )
    $ExcludeFiles = @(
        '*.zip', '*.7z', '*.rar', '*.tar', '*.gz', '*.iso',
        '*.jou', '*.log', '*.wdb', '*.vcd', '*.vpd', '*.fst',
        '*.bit', '*.mcs', '*.rpt', '*.str', '*.pb',
        '*.tmp', '*.swp', '*.pfx', '*.pem', '*.p12', '*.key', 'id_rsa', 'id_ed25519', '.npmrc', '.pypirc',
        '*.backup.jou', '*.backup.log', '.env', '.env.*'
    )
    $CopyArgs = @(
        $SourceDirectory, $Destination, '/E', '/XJ', '/R:1', '/W:1',
        '/MT:8', '/NFL', '/NDL', '/NP', '/NJH', '/NJS', '/XD'
    ) + $ExcludeDirs + @('/XF') + $ExcludeFiles
    & robocopy @CopyArgs
    $copyResult = $LASTEXITCODE
    if ($copyResult -ge 8) { throw ('File copying failed (robocopy code ' + $copyResult + ').') }

    # The local .gitignore is left untouched. Build known-safe rules in the upload copy.
    $ignore = @'
# Vivado FPGA: keep design sources; ignore reproducible generated files.
.Xil/
*.cache/
*.runs/
*.sim/
*.gen/
*.hw/
*.ip_user_files/

# Large or generated output / archives
*.zip
*.7z
*.rar
*.tar
*.gz
*.iso
*.log
*.jou
*.wdb
*.vcd
*.vpd
*.fst
*.bit
*.mcs
*.rpt
*.str
*.pb
*.tmp
*.swp

# Credentials and local machine state
.env
.env.*
*.pem
*.pfx
id_rsa
id_ed25519
__pycache__/
.venv/
node_modules/
'@
    [System.IO.File]::WriteAllText((Join-Path $Destination '.gitignore'), $ignore + "`r`n", ([System.Text.UTF8Encoding]::new($false)))

    # GitHub ordinary Git blocks files >= 100 MiB. Skip files >= 49 MiB for safe uploads.
    $MaxFileBytes = 49MB
    $tooLarge = @(Get-ChildItem -LiteralPath $Destination -Recurse -File -Force | Where-Object { $_.Length -ge $MaxFileBytes })
    if ($tooLarge.Count -gt 0) {
        Write-Host ('Skipping ' + $tooLarge.Count + ' large file(s), each 49 MiB or larger:') -ForegroundColor Yellow
        foreach ($item in $tooLarge) {
            Write-Host ('  ' + $item.FullName.Substring($Destination.Length + 1) + ' (' + [math]::Round($item.Length / 1MB, 1) + ' MiB)')
            Remove-Item -LiteralPath $item.FullName -Force
        }
    }
    $essential = @(Get-ChildItem -LiteralPath $Destination -Filter '*.xpr' -File)
    if ($essential.Count -eq 0) { throw 'Vivado .xpr was not included after copying. No upload performed.' }

    Step 'Committing project files on the main branch'
    Invoke-Git -Arguments @('-C', $TempRepository, 'add', '--all', '--', $ProjectName)
    $trackedXpr = @(& $script:GitPath -C $TempRepository ls-files -- ($ProjectName + '/*.xpr'))
    if ($trackedXpr.Count -eq 0) {
        throw 'The Vivado .xpr file was ignored by Git rules. No upload performed.'
    }
    & $script:GitPath -C $TempRepository diff --cached --quiet
    $status = $LASTEXITCODE
    if ($status -eq 1) {
        $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
        Invoke-Git -Arguments @('-C', $TempRepository, '-c', 'user.name=Charon-PF', '-c', 'user.email=Charon-PF@users.noreply.github.com', 'commit', '-m', ('Upload Vivado ' + $ProjectName + ' - ' + $stamp))
    } elseif ($status -eq 0) {
        Write-Host 'No changes to commit. The GitHub repository is already up to date.'
    } else {
        throw 'Git could not check which files were changed.'
    }

    Step 'Pushing to GitHub'
    & $script:GitPath -C $TempRepository push -u origin $Branch
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'First push failed. Trying to synchronize remote changes safely...' -ForegroundColor Yellow
        Invoke-Git -Arguments @('-C', $TempRepository, 'pull', '--rebase', 'origin', $Branch)
        Invoke-Git -Arguments @('-C', $TempRepository, 'push', '-u', 'origin', $Branch)
    }

    Step 'Verifying the uploaded branch'
    $localCommit = (& $script:GitPath -C $TempRepository rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the local Git commit.' }
    $remoteRef = @(& $script:GitPath -C $TempRepository ls-remote --heads origin $Branch)
    if ($LASTEXITCODE -ne 0 -or $remoteRef.Count -eq 0) { throw 'Cannot verify GitHub main branch.' }
    $remoteCommit = ($remoteRef[0] -split '\s+')[0]
    if ($remoteCommit -ne $localCommit) { throw 'GitHub verification did not match the local commit.' }

    $UploadSucceeded = $true
    $projectUrl = $RepositoryPage + '/tree/main/' + [uri]::EscapeDataString($ProjectName)
    Write-Host ''
    Write-Host '======================================================' -ForegroundColor Green
    Write-Host '  VERIFIED: Upload succeeded!' -ForegroundColor Green
    Write-Host ('  ' + $projectUrl) -ForegroundColor Green
    Write-Host '======================================================' -ForegroundColor Green
    try { Start-Process $projectUrl -ErrorAction Stop } catch { Write-Host 'Open the URL above in your browser.' }
}
catch {
    Write-Host ''
    Write-Host 'UPLOAD FAILED - no force push or deletion was performed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if (Test-Path -LiteralPath $TempRepository -PathType Container) {
        Write-Host ('Temporary working copy (for troubleshooting): ' + $TempRepository) -ForegroundColor Yellow
    }
    Write-Host 'Common fixes: sign in to GitHub when prompted; ensure your account can write to Charon-PF/FPGA; check Internet access.' -ForegroundColor Yellow
    exit 1
}
finally {
    if ($UploadSucceeded -and (Test-Path -LiteralPath $TempRepository -PathType Container)) {
        Remove-Item -LiteralPath $TempRepository -Recurse -Force -ErrorAction SilentlyContinue
    }
}
exit 0
