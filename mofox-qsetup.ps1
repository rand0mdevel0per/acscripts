# MoFox-Core 一键部署脚本 v2.0
# 适用于 Windows 10/11
# 优先使用系统已安装的 Python 和 Git

param(
    [string]$InstallPath = $PWD
)

# 设置错误处理和编码
$ErrorActionPreference = "Stop"
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 配置常量
$PYTHON_URL = "https://www.python.org/ftp/python/3.15.0/python-3.15.0a5-embed-amd64.zip"
$GIT_URL = "https://hk.gh-proxy.org/https://github.com/git-for-windows/git/releases/download/v2.53.0.windows.1/PortableGit-2.53.0-64-bit.7z.exe"
$REPO_URL = "https://hk.gh-proxy.org/https://github.com/MoFox-Studio/MoFox-Core.git"
$NAPCAT_URL = "https://hk.gh-proxy.org/https://github.com/NapNeko/NapCatQQ/releases/latest/NapCat.Shell.Windows.OneKey.zip"

# 颜色输出函数
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step { param([string]$Message); Write-ColorOutput "`n==> $Message" "Cyan" }
function Write-Success { param([string]$Message); Write-ColorOutput "✓ $Message" "Green" }
function Write-ErrorMsg { param([string]$Message); Write-ColorOutput "✗ $Message" "Red" }
function Write-WarningMsg { param([string]$Message); Write-ColorOutput "⚠ $Message" "Yellow" }
function Write-Info { param([string]$Message); Write-ColorOutput "ℹ $Message" "Gray" }

# 检测系统 Python（优先使用系统版本）
function Get-PythonExecutable {
    param([string]$InstallDir)

    Write-Step "检查 Python 环境..."

    # 优先检测系统 Python
    try {
        $pythonVersion = python --version 2>&1
        if ($pythonVersion -match "Python (\d+)\.(\d+)") {
            $major = [int]$matches[1]
            $minor = [int]$matches[2]
            if ($major -ge 3 -and $minor -ge 11) {
                Write-Success "检测到系统 Python: $pythonVersion"
                return "python"
            }
            else {
                Write-WarningMsg "系统 Python 版本过低: $pythonVersion (需要 >= 3.11)"
            }
        }
    }
    catch {
        Write-Info "未检测到系统 Python"
    }

    # 检查便携版 Python
    $pythonDir = Join-Path $InstallDir "python"
    $pythonExe = Join-Path $pythonDir "python.exe"

    if (Test-Path $pythonExe) {
        Write-Success "检测到便携版 Python: $pythonDir"
        return $pythonExe
    }

    # 询问是否安装便携版
    Write-WarningMsg "未找到合适的 Python 环境"
    $response = Read-Host "是否下载并安装便携版 Python 3.15？(Y/n)"

    if ($response -eq "" -or $response -eq "Y" -or $response -eq "y") {
        return Install-PortablePython -InstallDir $InstallDir
    }
    else {
        Write-ErrorMsg "需要 Python >= 3.11 才能继续"
        return $null
    }
}

# 检测系统 Git（优先使用系统版本）
function Get-GitExecutable {
    param([string]$InstallDir)

    Write-Step "检查 Git 环境..."

    # 优先检测系统 Git
    try {
        $gitVersion = git --version 2>&1
        Write-Success "检测到系统 Git: $gitVersion"
        return "git"
    }
    catch {
        Write-Info "未检测到系统 Git"
    }

    # 检查便携版 Git
    $gitDir = Join-Path $InstallDir "git"
    $gitExe = Join-Path $gitDir "bin\git.exe"

    if (Test-Path $gitExe) {
        Write-Success "检测到便携版 Git: $gitDir"
        return $gitExe
    }

    # 询问是否安装便携版
    Write-WarningMsg "未找到 Git"
    $response = Read-Host "是否下载并安装便携版 Git？(Y/n)"

    if ($response -eq "" -or $response -eq "Y" -or $response -eq "y") {
        return Install-PortableGit -InstallDir $InstallDir
    }
    else {
        Write-ErrorMsg "需要 Git 才能继续"
        return $null
    }
}

# 检测或安装 uv（优先使用系统版本）
function Install-UV {
    param([string]$PythonExe)

    Write-Step "检查 uv 包管理器..."

    # 优先检测系统 uv
    try {
        $uvVersion = uv --version 2>&1
        Write-Success "检测到系统 uv: $uvVersion"
        return $true
    }
    catch {
        Write-Info "未检测到系统 uv"
    }

    # 安装 uv
    Write-Info "正在安装 uv..."
    try {
        & $PythonExe -m pip install uv
        Write-Success "uv 安装完成"
        return $true
    }
    catch {
        Write-ErrorMsg "uv 安装失败: $_"
        return $false
    }
}

# 下载文件
function Get-File {
    param([string]$Url, [string]$OutputPath, [string]$Description)
    Write-Info "下载 $Description..."
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        Write-Success "下载完成"
        return $true
    }
    catch {
        Write-ErrorMsg "下载失败: $_"
        return $false
    }
}

# 安装便携版 Python
function Install-PortablePython {
    param([string]$InstallDir)
    $pythonDir = Join-Path $InstallDir "python"
    $pythonExe = Join-Path $pythonDir "python.exe"
    $zipPath = Join-Path $InstallDir "python.zip"

    if (-not (Get-File -Url $PYTHON_URL -OutputPath $zipPath -Description "Python 3.15")) {
        return $null
    }

    Write-Info "解压 Python..."
    Expand-Archive -Path $zipPath -DestinationPath $pythonDir -Force
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

    # 配置 Python 环境
    $pthFile = Join-Path $pythonDir "python315._pth"
    @"
python315.zip
.
Lib
Lib\site-packages
import site
"@ | Set-Content -Path $pthFile -Encoding UTF8

    Write-Success "便携版 Python 安装完成"
    return $pythonExe
}

# 安装便携版 Git
function Install-PortableGit {
    param([string]$InstallDir)
    $gitDir = Join-Path $InstallDir "git"
    $gitExe = Join-Path $gitDir "bin\git.exe"
    $exePath = Join-Path $InstallDir "PortableGit.exe"

    if (-not (Get-File -Url $GIT_URL -OutputPath $exePath -Description "Git")) {
        return $null
    }

    Write-Info "解压 Git..."
    $process = Start-Process -FilePath $exePath -ArgumentList "-o`"$gitDir`"", "-y" -Wait -PassThru -NoNewWindow
    Remove-Item $exePath -Force -ErrorAction SilentlyContinue

    if ($process.ExitCode -eq 0) {
        Write-Success "便携版 Git 安装完成"
        return $gitExe
    }
    else {
        Write-ErrorMsg "Git 安装失败"
        return $null
    }
}

function Install-NapCat {
    param([string]$InstallDir)

    Write-Step "安装 NapCat 一键版"

    $napcatDir = Join-Path $InstallDir "NapCat"
    $zipPath = Join-Path $InstallDir "NapCat.zip"

    # 检查是否已安装
    if (Test-Path $napcatDir) {
        $existingShell = Get-ChildItem -Path $napcatDir -Filter "NapCat.*.Shell" -Directory | Select-Object -First 1
        if ($existingShell) {
            Write-Success "检测到已安装的 NapCat: $($existingShell.FullName)"
            $napcatBat = Join-Path $existingShell.FullName "napcat.bat"
            if (Test-Path $napcatBat) {
                return $existingShell.FullName
            }
        }
    }

    # 下载 NapCat
    if (-not (Get-File -Url $NAPCAT_URL -OutputPath $zipPath -Description "NapCat 一键版")) {
        return $null
    }

    # 解压
    Write-Info "解压 NapCat..."
    try {
        if (-not (Test-Path $napcatDir)) {
            New-Item -ItemType Directory -Path $napcatDir -Force | Out-Null
        }
        Expand-Archive -Path $zipPath -DestinationPath $napcatDir -Force
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Write-Success "解压完成"
    }
    catch {
        Write-ErrorMsg "解压失败: $_"
        return $null
    }

    # 运行自动化配置
    $installerPath = Join-Path $napcatDir "NapCatInstaller.exe"
    if (Test-Path $installerPath) {
        Write-Info "运行 NapCat 自动化配置..."
        try {
            $process = Start-Process -FilePath $installerPath -WorkingDirectory $napcatDir -Wait -PassThru -NoNewWindow
            if ($process.ExitCode -eq 0) {
                Write-Success "NapCat 配置完成"
            }
            else {
                Write-WarningMsg "NapCat 配置可能未完全完成 (退出码: $($process.ExitCode))"
            }
        }
        catch {
            Write-WarningMsg "自动化配置执行异常: $_"
        }
    }

    # 查找生成的 Shell 目录
    $shellDir = Get-ChildItem -Path $napcatDir -Filter "NapCat.*.Shell" -Directory | Select-Object -First 1
    if ($shellDir) {
        Write-Success "NapCat 安装完成: $($shellDir.FullName)"
        return $shellDir.FullName
    }
    else {
        Write-ErrorMsg "未找到 NapCat Shell 目录"
        return $null
    }
}

# 配置文件处理函数
function Set-ModelConfig {
    param([string]$ProjectPath, [string]$ApiKey)
    $templatePath = Join-Path $ProjectPath "template\model_config_template.toml"
    $configPath = Join-Path $ProjectPath "config\model_config.toml"

    if (-not (Test-Path $templatePath)) {
        Write-ErrorMsg "未找到模板文件: $templatePath"
        return $false
    }

    $configDir = Join-Path $ProjectPath "config"
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
    # 使用更精确的 regex 替换 API Key（支持单引号和双引号）
    $configContent = $templateContent -replace '(?m)^(\s*api_key\s*=\s*)["''].*?["'']', "`$1`"$ApiKey`""
    Set-Content -Path $configPath -Value $configContent -Encoding UTF8
    Write-Success "模型配置文件已创建"
    return $true
}

function Set-BotConfig {
    param([string]$ProjectPath, [string]$BotQQ, [string]$MasterQQ)
    $templatePath = Join-Path $ProjectPath "template\bot_config_template.toml"
    $configPath = Join-Path $ProjectPath "config\bot_config.toml"

    if (Test-Path $templatePath) {
        $templateContent = Get-Content $templatePath -Raw -Encoding UTF8
        # 使用更精确的 regex 替换 QQ 账号
        $configContent = $templateContent -replace '(?m)^(\s*qq_account\s*=\s*)["''].*?["'']', "`$1`"$BotQQ`""
        # 使用多行匹配替换 master_users（支持单行和多行格式）
        $configContent = $configContent -replace '(?ms)^(\s*master_users\s*=\s*)\[.*?\]', "`$1[[`"qq`", `"$MasterQQ`"]]"
    }
    else {
        $configContent = "qq_account = `"$BotQQ`"`nmaster_users = [[`"qq`", `"$MasterQQ`"]]"
    }

    Set-Content -Path $configPath -Value $configContent -Encoding UTF8
    Write-Success "机器人配置文件已创建"
    return $true
}

function Set-EnvFile {
    param([string]$ProjectPath)
    $templatePath = Join-Path $ProjectPath "template\template.env"
    $envPath = Join-Path $ProjectPath ".env"

    if (Test-Path $templatePath) {
        Copy-Item $templatePath $envPath -Force
    }
    else {
        Set-Content -Path $envPath -Value "EULA_CONFIRMED=true" -Encoding UTF8
    }
    Write-Success "环境文件已创建"
    return $true
}

# 初始化插件配置并启用 NapCat 适配器
function Initialize-PluginsAndNapCat {
    param([string]$ProjectPath, [string]$PythonExe)

    Write-Step "初始化插件配置..."
    Write-Info "正在运行 bot.py 生成插件配置文件..."

    try {
        # 运行一次 bot.py 生成插件配置
        $process = Start-Process -FilePath $PythonExe -ArgumentList "-m", "uv", "run", "python", "bot.py" -WorkingDirectory $ProjectPath -NoNewWindow -PassThru

        # 等待几秒让插件配置生成
        Start-Sleep -Seconds 5

        # 如果进程还在运行，停止它
        if (-not $process.HasExited) {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        }

        Write-Success "插件配置初始化完成"
    }
    catch {
        Write-WarningMsg "插件初始化可能未完全完成: $_"
    }

    # 启用 NapCat 适配器
    Write-Step "配置 NapCat 适配器..."
    $napcatConfigPath = Join-Path $ProjectPath "config\plugins\napcat_adapter\config.toml"

    if (Test-Path $napcatConfigPath) {
        $napcatConfig = Get-Content $napcatConfigPath -Raw -Encoding UTF8

        # 使用 regex 启用插件
        $napcatConfig = $napcatConfig -replace '(?m)^(\s*enabled\s*=\s*)false', '$1true'

        Set-Content -Path $napcatConfigPath -Value $napcatConfig -Encoding UTF8
        Write-Success "NapCat 适配器已启用"

        # 提取端口号
        if ($napcatConfig -match '(?m)^\s*port\s*=\s*(\d+)') {
            $napcatPort = $matches[1]
            Write-Info "NapCat WebSocket 端口: $napcatPort"
            return $napcatPort
        }
        else {
            Write-Info "NapCat WebSocket 端口（默认）: 8095"
            return "8095"
        }
    }
    else {
        Write-WarningMsg "未找到 NapCat 配置文件，请手动配置"
        return "8095"
    }
}

# 主部署流程
function Start-AutoDeployment {
    Write-ColorOutput @"

╔═══════════════════════════════════════════╗
║   MoFox-Core 一键部署脚本 v2.0           ║
║   适用于 Windows 10/11                    ║
╚═══════════════════════════════════════════╝

"@ "Magenta"

    Write-Info "安装目录: $InstallPath"
    Write-Info ""

    # 确保安装目录存在
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    # 步骤 1: 检查 Python
    Write-Step "步骤 1/8: 检查 Python 环境"
    $pythonExe = Get-PythonExecutable -InstallDir $InstallPath
    if (-not $pythonExe) {
        Write-ErrorMsg "Python 环境配置失败"
        return $false
    }

    # 步骤 2: 检查 Git
    Write-Step "步骤 2/8: 检查 Git 环境"
    $gitExe = Get-GitExecutable -InstallDir $InstallPath
    if (-not $gitExe) {
        Write-ErrorMsg "Git 环境配置失败"
        return $false
    }

    # 步骤 3: 检查 uv
    Write-Step "步骤 3/8: 检查 uv 包管理器"
    if (-not (Install-UV -PythonExe $pythonExe)) {
        Write-ErrorMsg "uv 安装失败"
        return $false
    }

    # 步骤 4: 克隆仓库
    Write-Step "步骤 4/8: 克隆 MoFox-Core 仓库"
    $repoPath = Join-Path $InstallPath "MoFox-Core"

    if (Test-Path $repoPath) {
        Write-WarningMsg "仓库已存在，跳过克隆"
    }
    else {
        try {
            if ($gitExe -ne "git") {
                $gitBinPath = Split-Path $gitExe -Parent
                $env:PATH = "$gitBinPath;$env:PATH"
            }
            & $gitExe clone $REPO_URL $repoPath
            Write-Success "仓库克隆成功"
        }
        catch {
            Write-ErrorMsg "仓库克隆失败: $_"
            return $false
        }
    }

    Set-Location $repoPath

    # 步骤 5: 创建虚拟环境和安装依赖
    Write-Step "步骤 5/8: 创建虚拟环境并安装依赖"

    if (-not (Test-Path ".venv")) {
        Write-Info "创建虚拟环境..."
        & $pythonExe -m uv venv
        Write-Success "虚拟环境创建完成"
    }
    else {
        Write-WarningMsg "虚拟环境已存在"
    }

    Write-Info "安装项目依赖（使用阿里云镜像）..."
    try {
        & $pythonExe -m uv pip install -r requirements.txt -i https://mirrors.aliyun.com/pypi/simple
        Write-Success "依赖安装完成"
    }
    catch {
        Write-ErrorMsg "依赖安装失败: $_"
        return $false
    }

    # 步骤 6: 配置机器人
    Write-Step "步骤 6/8: 配置机器人信息"
    Write-ColorOutput "`n请输入以下配置信息:" "Yellow"

    $botQQ = Read-Host "机器人 QQ 号"
    $masterQQ = Read-Host "管理员 QQ 号"
    $apiKey = Read-Host "SiliconFlow API Key (以 sk- 开头)"

    # 生成配置文件
    Write-Info "生成配置文件..."
    Set-EnvFile -ProjectPath $repoPath | Out-Null
    Set-BotConfig -ProjectPath $repoPath -BotQQ $botQQ -MasterQQ $masterQQ | Out-Null
    Set-ModelConfig -ProjectPath $repoPath -ApiKey $apiKey | Out-Null

    # 询问是否编辑配置
    Write-ColorOutput "`n是否要用记事本编辑配置文件？(y/N)" "Yellow"
    $editConfig = Read-Host

    if ($editConfig -eq "y" -or $editConfig -eq "Y") {
        Write-Info "打开配置文件..."
        Start-Process notepad (Join-Path $repoPath "config\bot_config.toml")
        Start-Process notepad (Join-Path $repoPath "config\model_config.toml")
        Start-Process notepad (Join-Path $repoPath ".env")
        Write-Info "编辑完成后请关闭记事本窗口"
        Read-Host "按 Enter 继续"
    }

    # 步骤 7: 初始化插件配置并启用 NapCat 适配器
    Write-Step "步骤 7/8: 初始化插件配置"
    $napcatPort = Initialize-PluginsAndNapCat -ProjectPath $repoPath -PythonExe $pythonExe

    # 步骤 8: 安装 NapCat
    Write-Step "步骤 8/8: 安装 NapCat QQ 客户端"
    $napcatPath = Install-NapCat -InstallDir $InstallPath
    if (-not $napcatPath) {
        Write-WarningMsg "NapCat 安装失败，请手动安装"
        $napcatPath = ""
    }

    return @{
        PythonExe   = $pythonExe
        GitExe      = $gitExe
        RepoPath    = $repoPath
        NapcatPort  = $napcatPort
        NapcatPath  = $napcatPath
    }
}

# 创建启动脚本
function New-StartScript {
    param(
        [string]$RepoPath,
        [string]$PythonExe,
        [string]$NapcatPath,
        [string]$NapcatPort
    )

    Write-Info "创建启动脚本..."

    # 创建 PowerShell 启动脚本（带自动启动 NapCat）
    $startPsContent = @"
# MoFox-Core 一键启动脚本
`$Host.UI.RawUI.WindowTitle = "MoFox-Core 启动器"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MoFox-Core 一键启动脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否是第一次启动
`$configMarker = Join-Path `$PSScriptRoot ".napcat_configured"
`$isFirstRun = -not (Test-Path `$configMarker)

# 启动 NapCat
if ("$NapcatPath" -ne "") {
    Write-Host "正在启动 NapCat QQ 客户端..." -ForegroundColor Green
    `$napcatBat = Join-Path "$NapcatPath" "napcat.bat"
    if (Test-Path `$napcatBat) {
        Start-Process -FilePath `$napcatBat -WorkingDirectory "$NapcatPath"
        Write-Host "✓ NapCat 已在新窗口启动" -ForegroundColor Green
        Write-Host ""

        if (`$isFirstRun) {
            Write-Host "检测到首次启动，需要完成 NapCat 配置" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "请在 NapCat 窗口中完成以下操作：" -ForegroundColor Yellow
            Write-Host "  1. 登录机器人 QQ 账号" -ForegroundColor White
            Write-Host "  2. 在 NapCat 网络配置中添加 WebSocket 客户端" -ForegroundColor White
            Write-Host "     URL: ws://127.0.0.1:$NapcatPort" -ForegroundColor Cyan
            Write-Host ""

            # 等待 NapCat 启动后打开浏览器
            Write-Host "等待 NapCat 启动..." -ForegroundColor Gray
            Start-Sleep -Seconds 5
            Write-Host "正在打开 NapCat WebUI..." -ForegroundColor Cyan
            Start-Process "http://127.0.0.1:6099"
            Write-Host ""

            Write-Host "配置完成后，" -ForegroundColor Yellow -NoNewline
            Read-Host "按 Enter 继续启动 MoFox-Core"

            # 创建配置标记文件
            New-Item -ItemType File -Path `$configMarker -Force | Out-Null
        }
        else {
            Write-Host "等待 NapCat 启动..." -ForegroundColor Gray
            Start-Sleep -Seconds 3
        }
    }
    else {
        Write-Host "⚠ 未找到 NapCat 启动文件，请手动启动" -ForegroundColor Yellow
    }
}
else {
    Write-Host "⚠ NapCat 未安装，请手动启动 NapCat QQ 客户端" -ForegroundColor Yellow
}

# 启动 MoFox-Core
Write-Host ""
Write-Host "正在启动 MoFox-Core..." -ForegroundColor Green
Set-Location `$PSScriptRoot

# 在新窗口启动 MoFox-Core
Start-Process powershell -ArgumentList "-NoExit", "-Command", "& {`$Host.UI.RawUI.WindowTitle='MoFox-Core Bot'; cd '`$PSScriptRoot'; & .\.venv\Scripts\Activate.ps1; python -m uv run python bot.py}"

Write-Host "✓ MoFox-Core 已在新窗口启动" -ForegroundColor Green
"@

    Set-Content -Path (Join-Path $RepoPath "start.ps1") -Value $startPsContent -Encoding UTF8
    Write-Success "创建 start.ps1"

    # 创建 BAT 启动脚本
    $startBatContent = @"
@echo off
chcp 65001 >nul
title MoFox-Core 启动器
echo ========================================
echo   MoFox-Core 一键启动脚本
echo ========================================
echo.

REM 检查是否是第一次启动
set "CONFIG_MARKER=%~dp0.napcat_configured"
if exist "%CONFIG_MARKER%" (
    set "IS_FIRST_RUN=0"
) else (
    set "IS_FIRST_RUN=1"
)

REM 启动 NapCat
if exist "$NapcatPath\napcat.bat" (
    echo 正在启动 NapCat QQ 客户端...
    start "" "$NapcatPath\napcat.bat"
    echo ✓ NapCat 已在新窗口启动
    echo.

    if "%IS_FIRST_RUN%"=="1" (
        echo 检测到首次启动，需要完成 NapCat 配置
        echo.
        echo 请在 NapCat 窗口中完成以下操作：
        echo   1. 登录机器人 QQ 账号
        echo   2. 在 NapCat 网络配置中添加 WebSocket 客户端
        echo      URL: ws://127.0.0.1:$NapcatPort
        echo.

        REM 等待 NapCat 启动后打开浏览器
        echo 等待 NapCat 启动...
        timeout /t 5 /nobreak >nul
        echo 正在打开 NapCat WebUI...
        start http://127.0.0.1:6099
        echo.

        echo 配置完成后，
        pause

        REM 创建配置标记文件
        echo. > "%CONFIG_MARKER%"
    ) else (
        echo 等待 NapCat 启动...
        timeout /t 3 /nobreak >nul
    )
) else (
    echo ⚠ NapCat 未安装，请手动启动 NapCat QQ 客户端
    echo.
)

REM 启动 MoFox-Core
echo.
echo 正在启动 MoFox-Core...
cd /d "%~dp0"
start "MoFox-Core Bot" cmd /k "call .venv\Scripts\activate.bat && python -m uv run python bot.py"
echo ✓ MoFox-Core 已在新窗口启动
"@

    Set-Content -Path (Join-Path $RepoPath "start.bat") -Value $startBatContent -Encoding UTF8
    Write-Success "创建 start.bat"
}

# 释放管理脚本
function Install-ManagerScript {
    param([string]$InstallPath)

    Write-Info "释放管理脚本..."

    $managerScriptContent = @'
# MoFox-Core 管理脚本
param([string]$ProjectPath = ".\MoFox-Core")

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-ColorOutput { param([string]$Message, [string]$Color = "White"); Write-Host $Message -ForegroundColor $Color }
function Write-Menu {
    Clear-Host
    Write-ColorOutput @"

╔═══════════════════════════════════════════╗
║      MoFox-Core 管理脚本 v1.0            ║
╚═══════════════════════════════════════════╝

"@ "Magenta"
    Write-ColorOutput "项目路径: $ProjectPath" "Gray"
    Write-ColorOutput ""
    Write-ColorOutput "请选择操作：" "Cyan"
    Write-ColorOutput "  1. 启动机器人" "White"
    Write-ColorOutput "  2. 停止机器人" "White"
    Write-ColorOutput "  3. 重启机器人" "White"
    Write-ColorOutput "  4. 查看日志" "White"
    Write-ColorOutput "  5. 更新代码" "White"
    Write-ColorOutput "  6. 编辑配置文件" "White"
    Write-ColorOutput "  7. 重新安装依赖" "White"
    Write-ColorOutput "  8. 打开 WebUI" "White"
    Write-ColorOutput "  9. 查看运行状态" "White"
    Write-ColorOutput "  0. 退出" "White"
    Write-ColorOutput ""
}

function Test-ProjectPath {
    if (-not (Test-Path $ProjectPath)) {
        Write-ColorOutput "错误：项目路径不存在: $ProjectPath" "Red"
        return $false
    }
    return $true
}

function Start-Bot {
    Write-ColorOutput "`n==> 启动机器人..." "Cyan"
    if (-not (Test-ProjectPath)) { return }
    Set-Location $ProjectPath
    $process = Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*bot.py*" }
    if ($process) {
        Write-ColorOutput "机器人已经在运行中 (PID: $($process.Id))" "Yellow"
        return
    }
    Write-ColorOutput "正在启动机器人..." "White"
    Start-Process -FilePath ".\start.ps1" -NoNewWindow
    Write-ColorOutput "机器人已启动" "Green"
}

function Stop-Bot {
    Write-ColorOutput "`n==> 停止机器人..." "Cyan"
    $processes = Get-Process -Name python -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*bot.py*" }
    if (-not $processes) {
        Write-ColorOutput "机器人未在运行" "Yellow"
        return
    }
    foreach ($process in $processes) {
        Write-ColorOutput "正在停止进程 (PID: $($process.Id))..." "White"
        Stop-Process -Id $process.Id -Force
    }
    Write-ColorOutput "机器人已停止" "Green"
}

function Restart-Bot {
    Write-ColorOutput "`n==> 重启机器人..." "Cyan"
    Stop-Bot
    Start-Sleep -Seconds 2
    Start-Bot
}
'@

    $managerPath = Join-Path $InstallPath "mofox-manager.ps1"
    Set-Content -Path $managerPath -Value $managerScriptContent -Encoding UTF8
    Write-Success "管理脚本已释放: mofox-manager.ps1"
}

# 主执行流程
try {
    $result = Start-AutoDeployment

    if ($result -and $result -is [hashtable]) {
        $pythonExe = $result.PythonExe
        $gitExe = $result.GitExe
        $repoPath = $result.RepoPath
        $napcatPort = $result.NapcatPort
        $napcatPath = $result.NapcatPath

        # 创建启动脚本
        New-StartScript -RepoPath $repoPath -PythonExe $pythonExe -NapcatPath $napcatPath -NapcatPort $napcatPort

        # 释放管理脚本
        Install-ManagerScript -InstallPath $InstallPath

        # 显示完成信息
        Write-ColorOutput "`n╔═══════════════════════════════════════════╗" "Green"
        Write-ColorOutput "║          部署完成！                       ║" "Green"
        Write-ColorOutput "╚═══════════════════════════════════════════╝" "Green"

        Write-ColorOutput "`n下一步操作：" "Cyan"
        Write-ColorOutput "1. 运行一键启动脚本：" "White"
        Write-ColorOutput "   - 双击 start.bat (命令提示符)" "Yellow"
        Write-ColorOutput "   - 或运行 start.ps1 (PowerShell)" "Yellow"
        Write-ColorOutput "`n2. 启动脚本会自动：" "White"
        Write-ColorOutput "   - 启动 NapCat QQ 客户端（新窗口）" "Gray"
        Write-ColorOutput "   - 启动 MoFox-Core 机器人（新窗口）" "Gray"
        Write-ColorOutput "   - 打开浏览器到 NapCat WebUI (http://127.0.0.1:6099)" "Gray"
        Write-ColorOutput "`n3. 在 NapCat WebUI 中完成配置：" "White"
        Write-ColorOutput "   - 登录机器人 QQ 账号" "Gray"
        Write-ColorOutput "   - 在网络配置中添加 WebSocket 客户端" "Gray"
        Write-ColorOutput "   - URL: ws://127.0.0.1:$napcatPort" "Yellow"
        Write-ColorOutput "`n4. 使用管理脚本管理机器人：" "White"
        Write-ColorOutput "   - 运行 mofox-manager.ps1" "Yellow"

        Write-ColorOutput "`n项目路径: $repoPath" "Cyan"
        Write-ColorOutput "Python: $pythonExe" "Cyan"
        Write-ColorOutput "Git: $gitExe" "Cyan"
        if ($napcatPath) {
            Write-ColorOutput "NapCat: $napcatPath" "Cyan"
        }

        Write-ColorOutput "`n部署成功完成！" "Green"
    }
    else {
        Write-ColorOutput "`n部署失败，请检查错误信息" "Red"
        exit 1
    }
}
catch {
    Write-ErrorMsg "部署过程中发生错误: $_"
    exit 1
}

Write-ColorOutput "`n按任意键退出..." "Gray"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
