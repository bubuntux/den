# bbtux's environment on Windows: through WSL when a distro is installed,
# otherwise in a podman/docker container.
#   irm https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap/bootstrap.ps1 | iex
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap/bootstrap.ps1))) -Container
param(
    [switch]$Container
)

$ErrorActionPreference = 'Stop'

$denFlake = if ($env:DEN_FLAKE) { $env:DEN_FLAKE } else { 'github:bubuntux/den' }
$denRaw = if ($env:DEN_RAW) { $env:DEN_RAW } else { 'https://raw.githubusercontent.com/bubuntux/den/main/scripts/bootstrap' }
$denImage = if ($env:DEN_IMAGE) { $env:DEN_IMAGE } else { 'bbtux-env' }

function Write-Step($message) {
    Write-Host "==> $message" -ForegroundColor Blue
}

function Test-Command($name) {
    [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Test-WslDistro {
    if (-not (Test-Command 'wsl.exe')) { return $false }
    & wsl.exe --exec true 2>$null | Out-Null
    $LASTEXITCODE -eq 0
}

function Invoke-Wsl {
    Write-Step 'Running bootstrap.sh inside the default WSL distro'
    & wsl.exe --exec sh -c "curl -fsSL '$denRaw/bootstrap.sh' | DEN_FLAKE='$denFlake' sh"
    if ($LASTEXITCODE -ne 0) { throw "bootstrap.sh failed in WSL (exit $LASTEXITCODE)" }
}

function Invoke-Container {
    $engine = @('podman', 'docker') | Where-Object { Test-Command $_ } | Select-Object -First 1
    if (-not $engine) {
        throw 'Neither podman nor docker is on PATH. Install Podman Desktop or Docker Desktop, or run `wsl --install` and reboot.'
    }

    $context = Join-Path ([System.IO.Path]::GetTempPath()) ("bbtux-env-" + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $context | Out-Null
    try {
        Write-Step "Fetching Containerfile from $denRaw"
        Invoke-WebRequest -UseBasicParsing "$denRaw/Containerfile" -OutFile (Join-Path $context 'Containerfile')

        Write-Step "Building $denImage with $engine (first build downloads a few GB)"
        & $engine build --build-arg "DEN_FLAKE=$denFlake" -t $denImage -f (Join-Path $context 'Containerfile') $context
        if ($LASTEXITCODE -ne 0) { throw "$engine build failed (exit $LASTEXITCODE)" }
    }
    finally {
        Remove-Item -Recurse -Force $context
    }

    $runArgs = @('run', '-it', '--rm', '-v', "${PWD}:/work")
    if ($engine -eq 'podman') { $runArgs += '--userns=keep-id:uid=1000,gid=1000' }

    Write-Step "Entering $denImage; $PWD is mounted at /work"
    & $engine @runArgs $denImage
}

if ($Container) {
    Invoke-Container
}
elseif (Test-WslDistro) {
    Invoke-Wsl
}
elseif ((Test-Command 'podman') -or (Test-Command 'docker')) {
    Write-Step 'No WSL distro found; falling back to a container'
    Invoke-Container
}
else {
    throw 'Need WSL or a container engine. Run `wsl --install` (then reboot), or install Podman Desktop / Docker Desktop, and re-run.'
}
