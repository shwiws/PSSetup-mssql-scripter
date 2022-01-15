Set-Location $PSScriptRoot
$settings = Get-Content "Setup.Config.json" | ConvertFrom-Json

# �r�b�g�����o���Ă���ɍ���python���擾����B
$os = Get-WmiObject -Class Win32_OperatingSystem
if (-not ($os.OSArchitecture -match "\d+")) {
    Write-Host "�r�b�g�����o�ł��܂���ł����B"
    Write-Host "�I�����܂��B"
    Pause
    return
}

$bit = $Matches[0]
$osVersion = $settings.python | Select-Object $bit -ExpandProperty $bit
$downloadUrl = $settings.python.urlFormat -f $settings.python.version,$osVersion

# �𓀍ς݂̃t�@�C�������݂��Ă�����폜����B
if (Test-Path -Path $settings.python.diretoryName) {
    Write-Host "�O��̃C���X�g�[���t�H���_���폜���܂��B:$($settings.python.diretoryName)`n"
    Remove-Item -Path $settings.python.diretoryName -Recurse -Force
}
if (Test-Path -Path $settings.python.dlFile) {
    Write-Host "�O��̃_�E�����[�h������܂��B�_�E�����[�h���X�L�b�v���܂��B`n"
}
else {
    # �_�E�����[�h���ĉ𓀂���B
    Write-Host "Python���_�E�����[�h���܂��B"
    Write-Host "URL:$downloadUrl"
    Invoke-WebRequest -Method Get -Uri $downloadUrl -OutFile $settings.python.dlFile
}

Write-Host "ZIP���𓀂��܂��B"
Write-Host "�Ώۃt�@�C��:$($settings.python.dlFile)"
Write-Host "�𓀐�:$($settings.python.diretoryName)`n"

Expand-Archive -Path $settings.python.dlFile -DestinationPath $settings.python.diretoryName

# Python�̊��ݒ�
Push-Location $settings.python.diretoryName
Write-Host "Python�̏����ݒ�ƃp�b�P�[�W�̃C���X�g�[�����s���܂��B`n"

#_pth�t�@�C�����X�V
$pthFile = Get-ChildItem python*._pth
$settings.python.pthFileAdd | Add-Content -Path $pthFile.FullName

# pip�̃C���X�g�[��
Write-Host "pip���C���X�g�[�����܂��B`n"
Invoke-WebRequest -Method Get -Uri $settings.pip.url -OutFile get-pip.py
.\python.exe get-pip.py

# �p�X�Ɉꎞ�I�ɐݒ肵�Ċe�p�b�P�[�W�̃C���X�g�[��
$env:Path += ";$((Resolve-Path "Scripts").Path))"
$settings.packages | ForEach-Object {
    Write-Host "[pip install]$_ ���C���X�g�[�����܂��B`n"
    .\python.exe -m pip install $_ 
}

Pop-Location

Write-Host "�������܂����B`n"

pause
