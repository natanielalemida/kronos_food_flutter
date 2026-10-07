$ErrorActionPreference = 'Stop'
$taskProject = Split-Path -Parent $PSScriptRoot
$taskConfig = Join-Path $taskProject 'config\ifood_homologacao.json'
Push-Location -LiteralPath $taskProject
try {
    flutter build windows --release "--dart-define-from-file=$taskConfig"
    if ($LASTEXITCODE -ne 0) {
        throw "Falha na build do Food: codigo $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
