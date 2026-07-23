# setup-opencode.ps1 — Bootstrap opencode on a new Windows machine
# Run: powershell -ExecutionPolicy Bypass -File setup-opencode.ps1
# After running, restore your backups: SSH keys + .env + SECRETS.md

$ErrorActionPreference = "Stop"
$OpencodeConfigDir = "$env:USERPROFILE\.config\opencode"
$HomeLabDir = "$env:USERPROFILE\HomeLab"
$RepoUrl = "https://github.com/noman-nkhl/HomeLab.git"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  opencode Homelab Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Install winget packages (Node.js, Git) ---
Write-Host "[1/5] Checking prerequisites..." -ForegroundColor Yellow

$needNode = -not (Get-Command node -ErrorAction SilentlyContinue)
$needGit = -not (Get-Command git -ErrorAction SilentlyContinue)

if ($needNode) {
    Write-Host "  Installing Node.js (LTS) via winget..." -ForegroundColor Gray
    winget install --id OpenJS.NodeJS.LTS --silent --accept-package-agreements 2>&1 | Out-Null
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Node.js installed: $(node --version)" -ForegroundColor Green
} else {
    Write-Host "  Node.js found: $(node --version)" -ForegroundColor Green
}

if ($needGit) {
    Write-Host "  Installing Git via winget..." -ForegroundColor Gray
    winget install --id Git.Git --silent --accept-package-agreements 2>&1 | Out-Null
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  Git installed: $(git --version)" -ForegroundColor Green
} else {
    Write-Host "  Git found: $(git --version)" -ForegroundColor Green
}

# --- Step 2: Install opencode ---
Write-Host ""
Write-Host "[2/5] Installing opencode CLI..." -ForegroundColor Yellow

if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Write-Host "  opencode already installed: $(opencode --version)" -ForegroundColor Green
} else {
    npm install -g opencode-ai 2>&1 | Out-Null
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Write-Host "  opencode installed: $(opencode --version)" -ForegroundColor Green
}

# --- Step 3: Clone HomeLab repo ---
Write-Host ""
Write-Host "[3/5] Cloning HomeLab repository..." -ForegroundColor Yellow

if (Test-Path "$HomeLabDir\.git") {
    Write-Host "  Repo exists. Pulling latest..." -ForegroundColor Gray
    Set-Location $HomeLabDir
    git pull origin master 2>&1 | Out-Null
    Write-Host "  Repo updated" -ForegroundColor Green
} else {
    git clone $RepoUrl $HomeLabDir 2>&1 | Out-Null
    Write-Host "  Repo cloned to $HomeLabDir" -ForegroundColor Green
}

# --- Step 4: Set up opencode config ---
Write-Host ""
Write-Host "[4/5] Setting up opencode configuration..." -ForegroundColor Yellow

if (Test-Path "$OpencodeConfigDir") {
    Write-Host "  Config directory exists. Backing up..." -ForegroundColor Gray
    $backupDir = "$OpencodeConfigDir.bak.$(Get-Date -Format yyyyMMdd-HHmmss)"
    Move-Item $OpencodeConfigDir $backupDir
    Write-Host "  Backed up to $backupDir" -ForegroundColor Gray
}

New-Item -ItemType Directory -Force -Path $OpencodeConfigDir | Out-Null

if (Test-Path "$HomeLabDir\opencode-config") {
    Copy-Item -Recurse -Force "$HomeLabDir\opencode-config\*" "$OpencodeConfigDir\"
    Write-Host "  Config files copied from repo" -ForegroundColor Green
} else {
    Write-Host "  ERROR: opencode-config not found in repo!" -ForegroundColor Red
    exit 1
}

# --- Step 5: Install opencode plugins ---
Write-Host ""
Write-Host "[5/5] Installing opencode plugins..." -ForegroundColor Yellow

Set-Location $OpencodeConfigDir
npm install 2>&1 | Out-Null
Write-Host "  Plugins installed" -ForegroundColor Green

# --- Done ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS (manual) — restore from your backup:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1. Copy your SSH keys to ~/.ssh/:" -ForegroundColor White
Write-Host "     copy homelab_ubuntu_docker      -> ~/.ssh/" -ForegroundColor Gray
Write-Host "     copy homelab_ubuntu_docker.pub  -> ~/.ssh/" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Copy secrets to $HomeLabDir\:" -ForegroundColor White
Write-Host "     copy .env        -> $HomeLabDir\" -ForegroundColor Gray
Write-Host "     copy SECRETS.md  -> $HomeLabDir\" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Set your DeepSeek API key as environment variable:" -ForegroundColor White
Write-Host "     [Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY', 'sk-...', 'User')" -ForegroundColor Gray
Write-Host "     (or configure in opencode settings)" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Start opencode:" -ForegroundColor White
Write-Host "     opencode" -ForegroundColor Gray
Write-Host ""
Write-Host "Your opencode VM is at: ssh nkhan3@192.168.1.51" -ForegroundColor Cyan
Write-Host ""
