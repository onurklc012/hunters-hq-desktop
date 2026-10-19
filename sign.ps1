# Authenticode-signs one file with a code-signing certificate from the Windows certificate store
# (CurrentUser\My, then LocalMachine\My). Cloud certificates such as Certum SimplySign show up there while
# their desktop tool is logged in. build.ps1 calls this for HuntersHQ.exe, and Inno Setup calls it for the
# setup and uninstaller.
#   sign.ps1 -Path file.exe [-Thumbprint ABC...]     (default: $env:HQ_SIGN_THUMBPRINT)
param([Parameter(Mandatory)][string]$Path, [string]$Thumbprint = $env:HQ_SIGN_THUMBPRINT,
      [string]$Timestamp = $(if ($env:HQ_SIGN_TIMESTAMP) { $env:HQ_SIGN_TIMESTAMP } else { 'http://time.certum.pl' }))
$ErrorActionPreference = 'Stop'
if (-not $Thumbprint) { throw 'no certificate: set HQ_SIGN_THUMBPRINT or pass -Thumbprint' }
$Thumbprint = $Thumbprint -replace '[^0-9A-Fa-f]', ''
$cert = Get-ChildItem Cert:\CurrentUser\My, Cert:\LocalMachine\My -CodeSigningCert |
    Where-Object Thumbprint -eq $Thumbprint | Select-Object -First 1
if (-not $cert) { throw "code-signing certificate $Thumbprint not found (is SimplySign Desktop logged in?)" }

# the timestamp server keeps the signature valid after the certificate expires; it is retried, it sometimes times out
foreach ($try in 1..3) {
    $r = Set-AuthenticodeSignature -LiteralPath $Path -Certificate $cert -HashAlgorithm SHA256 `
        -TimestampServer $Timestamp -IncludeChain NotRoot
    if ($r.Status -in 'Valid', 'UnknownError' -and $r.SignerCertificate) { break }
    if ($try -eq 3) { throw "signing $Path failed: $($r.Status) $($r.StatusMessage)" }
    Start-Sleep 5
}
"signed: $Path ($($r.Status))"
