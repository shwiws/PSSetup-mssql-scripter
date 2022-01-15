Set-Location $PSScriptRoot
$settings = Get-Content "Setup.Config.json" | ConvertFrom-Json

# ビットを検出してそれに合うpythonを取得する。
$os = Get-WmiObject -Class Win32_OperatingSystem
if (-not ($os.OSArchitecture -match "\d+")) {
    Write-Host "ビットを検出できませんでした。"
    Write-Host "終了します。"
    Pause
    return
}

$bit = $Matches[0]
$osVersion = $settings.python | Select-Object $bit -ExpandProperty $bit
$downloadUrl = $settings.python.urlFormat -f $settings.python.version,$osVersion

# 解凍済みのファイルが存在していたら削除する。
if (Test-Path -Path $settings.python.diretoryName) {
    Write-Host "前回のインストールフォルダを削除します。:$($settings.python.diretoryName)`n"
    Remove-Item -Path $settings.python.diretoryName -Recurse -Force
}
if (Test-Path -Path $settings.python.dlFile) {
    Write-Host "前回のダウンロードがあります。ダウンロードをスキップします。`n"
}
else {
    # ダウンロードして解凍する。
    Write-Host "Pythonをダウンロードします。"
    Write-Host "URL:$downloadUrl"
    Invoke-WebRequest -Method Get -Uri $downloadUrl -OutFile $settings.python.dlFile
}

Write-Host "ZIPを解凍します。"
Write-Host "対象ファイル:$($settings.python.dlFile)"
Write-Host "解凍先:$($settings.python.diretoryName)`n"

Expand-Archive -Path $settings.python.dlFile -DestinationPath $settings.python.diretoryName

# Pythonの環境設定
Push-Location $settings.python.diretoryName
Write-Host "Pythonの初期設定とパッケージのインストールを行います。`n"

#_pthファイルを更新
$pthFile = Get-ChildItem python*._pth
$settings.python.pthFileAdd | Add-Content -Path $pthFile.FullName

# pipのインストール
Write-Host "pipをインストールします。`n"
Invoke-WebRequest -Method Get -Uri $settings.pip.url -OutFile get-pip.py
.\python.exe get-pip.py

# パスに一時的に設定して各パッケージのインストール
$env:Path += ";$((Resolve-Path "Scripts").Path))"
$settings.packages | ForEach-Object {
    Write-Host "[pip install]$_ をインストールします。`n"
    .\python.exe -m pip install $_ 
}

Pop-Location

Write-Host "完了しました。`n"

pause
