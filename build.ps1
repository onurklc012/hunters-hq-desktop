# Builds the Hunters HQ Windows installer: <out>\HuntersHQ-Setup.exe (+ .sha256).
#   powershell -ExecutionPolicy Bypass -File build.ps1 [-Version 1.0.1] [-Stage all|app|installer] [-OutDir dir]
# Stages: app = build venv (from requirements.txt) + PyInstaller one-folder bundle (<out>\build\dist\HuntersHQ);
# installer = Inno Setup per-user installer from that bundle. The release workflow runs them separately so the
# exe can be signed in between. Needs Python 3.12 and Inno Setup 6 (winget install JRSoftware.InnoSetup).
# Output: -OutDir, else C:\HuntersHQ\data\member-app when this runs on the Hunters HQ server, else .\out.
# Local signing (optional): set HQ_SIGN_THUMBPRINT to a code-signing certificate in the Windows store and
# sign.ps1 signs the app, setup and uninstaller. Release builds are signed in CI instead (see README).
param([string]$Version = '1.0.0', [ValidateSet('all', 'app', 'installer')][string]$Stage = 'all', [string]$OutDir)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not $OutDir) {
    $server = Resolve-Path "$here\..\..\..\data" -ErrorAction SilentlyContinue      # C:\HuntersHQ\data
    $OutDir = if ($server -and (Test-Path "$here\..\..\..\backend\hq")) { Join-Path $server 'member-app' } else { "$here\out" }
}
$out = (New-Item -ItemType Directory -Force $OutDir).FullName
$build = Join-Path $out 'build'
$dist = Join-Path $build 'dist\HuntersHQ'
$venv = Join-Path $build 'venv'
$py = Join-Path $venv 'Scripts\python.exe'
$icon = (Resolve-Path "$here\assets\hunters-hq.ico").Path
$sign = [bool]$env:HQ_SIGN_THUMBPRINT
New-Item -ItemType Directory -Force $build | Out-Null

$src = Get-Content "$here\hunters_hq.py" -Raw
if ($src -notmatch "VERSION = `"$([regex]::Escape($Version))`"") {
    throw "hunters_hq.py VERSION is not $Version; update it first so the app reports the same version"
}

if ($Stage -in 'all', 'app') {
    # 1. build environment (CI: the Python from actions/setup-python)
    if (-not (Test-Path $py)) {
        if ($env:pythonLocation) { & "$env:pythonLocation\python.exe" -m venv $venv }
        elseif (Get-Command py -ErrorAction SilentlyContinue) { & py -3.12 -m venv $venv }
        else { & python -m venv $venv }
        if (-not (Test-Path $py)) { throw 'could not create the build venv (Python 3.12 needed)' }
    }
    & $py -m pip install --disable-pip-version-check -q -r "$here\requirements.txt"
    if ($LASTEXITCODE) { throw 'pip install failed' }

    # 2. the exe's file properties
    $v = ($Version.Split('.') + @('0', '0', '0'))[0..3] -join ', '
    @"
VSVersionInfo(
  ffi=FixedFileInfo(filevers=($v), prodvers=($v)),
  kids=[StringFileInfo([StringTable('040904B0', [
    StringStruct('CompanyName', '101st Hunter Squadron'),
    StringStruct('FileDescription', 'Hunters HQ'),
    StringStruct('FileVersion', '$Version'),
    StringStruct('InternalName', 'HuntersHQ'),
    StringStruct('LegalCopyright', 'MIT License'),
    StringStruct('OriginalFilename', 'HuntersHQ.exe'),
    StringStruct('ProductName', 'Hunters HQ'),
    StringStruct('ProductVersion', '$Version')])]),
    VarFileInfo([VarStruct('Translation', [1033, 1200])])])
"@ | Set-Content -Encoding ascii "$build\version_info.txt"

    # 3. PyInstaller one-folder bundle (one-folder starts faster and trips antivirus less than one-file)
    & $py -m PyInstaller --noconfirm --clean --log-level WARN --windowed --name HuntersHQ `
        --icon $icon --add-data "$icon;." --version-file "$build\version_info.txt" `
        --exclude-module tkinter --exclude-module unittest --exclude-module pydoc `
        --distpath "$build\dist" --workpath "$build\work" --specpath $build `
        "$here\hunters_hq.py"
    if ($LASTEXITCODE) { throw 'PyInstaller failed' }

    if ($sign) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File "$here\sign.ps1" -Path "$dist\HuntersHQ.exe"
        if ($LASTEXITCODE) { throw 'signing HuntersHQ.exe failed' }
    }
    "app: $dist\HuntersHQ.exe"
}

if ($Stage -in 'all', 'installer') {
    # 4. installer
    if (-not (Test-Path "$dist\HuntersHQ.exe")) { throw "no app bundle in $dist (run -Stage app first)" }
    $iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
              "$env:ProgramFiles\Inno Setup 6\ISCC.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $iscc) { throw 'Inno Setup 6 not found: winget install JRSoftware.InnoSetup --scope user' }
    $isccArgs = @('/Q', "/DAppVersion=$Version", "/DDistDir=$dist", "/O$out")
    if ($sign) {   # Inno signs the setup and the uninstaller with the same script ($q = quote, $f = file)
        $isccArgs += '/DSign', "/Shqsign=powershell.exe -NoProfile -ExecutionPolicy Bypass -File `$q$here\sign.ps1`$q -Path `$f"
    }
    & $iscc @isccArgs "$here\installer.iss"
    if ($LASTEXITCODE) { throw 'Inno Setup failed' }

    $setup = Join-Path $out 'HuntersHQ-Setup.exe'
    $hash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()
    "$hash  HuntersHQ-Setup.exe" | Set-Content -Encoding ascii "$setup.sha256"
    "{0}  ({1:N1} MB)  sha256 {2}  signature: {3}" -f $setup, ((Get-Item $setup).Length / 1MB), $hash,
        (Get-AuthenticodeSignature $setup).Status
}
