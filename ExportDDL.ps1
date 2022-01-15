using namespace System.Runtime.InteropServices;
using namespace System.Data.SqlClient

# �ڑ�������̊m�F
# �ڑ���Open���ł����True��Ԃ��B���O�C�����[�U�[���̂̌����̓`�F�b�N�ł��Ȃ��̂Œ���
function IsConnectionStringValid {
    param (
        [Parameter(Mandatory)]
        [string]
        $connectionString
    )
    try { ([SqlConnection]::new($connectionString)).Open() }
    catch { return $false; }
    return $true;
}

function Main {
    # ���ϐ��ɐڑ��������ݒ�
    $ConfigFileName = "ExportDDL.Config.json"
    $config = Get-Content $ConfigFileName | ConvertFrom-Json
    if (-not (Test-Path -path $config.python.directoryPath)) {
        Throw "[�G���[]python���C���X�g�[������Ă��܂���B�I�����܂��B"
    }

    if (Test-Path -Path $config.login.connectionStringFile) {
        # �����̐ڑ�������t�@�C������ڑ��������ǂݍ���
        Write-Host "�ۑ����ꂽ�ڑ���񂩂�DB��`���o�͂��܂��B"

        $ss = Import-Clixml -Path $config.login.connectionStringFile
        $connectionString = [Marshal]::PtrToStringBSTR([Marshal]::SecureStringToBSTR($ss));
        if (-not (IsConnectionStringValid($connectionString))) {
            Remove-Item -Path $config.login.connectionStringFile -Force
            throw `
                "[�G���[]�ۑ����ꂽ�ڑ����Őڑ��Ɏ��s���܂����B`n" +
            "�ۑ����ꂽ�ڑ����t�@�C�����폜���܂����B`n" +
            "�p�X:$FilePath`n" +
            "�ēx���s���ĉ������B`n"
        }
    }
    else {
        # �V�K�ɐڑ�����������B
        Write-Host (`
                "���L�̐ݒ�Őڑ����܂��B`n" +
            "- �T�[�o�[:$($config.login.server)`n" +
            "- ���[�U�[:$($config.login.userId)`n" +
            "�����̐ݒ�Őڑ��������ꍇ�͐ݒ�t�@�C��[$ConfigFileName]���C�����ĉ������B`n" +
            "`n" +
            "�p�X���[�h����͂��ĉ������B`n" +
            "`n")

        [SecureString]$ssPass = Read-Host "�p�X���[�h" -AsSecureString
        [SqlConnectionStringBuilder]$builder = New-Object SqlConnectionStringBuilder -Property @{
            DataSource = $config.login.server
            UserID     = $config.login.userId
            Password   = [Marshal]::PtrToStringBSTR([Marshal]::SecureStringToBSTR($ssPass))
        }

        if (-not (IsConnectionStringValid($builder.ConnectionString))) {
            throw `
                "[�G���[]�ڑ��Ɏ��s���܂����B`n" +
            "�p�X���[�h���Ԉ���Ă���\��������܂��B`n" +
            "�m�F���čēx���s���ĉ������B`n"
        }

        # �ڑ����������ڑ�������̈Í��������ۑ�
        $ss = ConvertTo-SecureString $builder.ConnectionString -AsPlainText -Force
        Export-Clixml -Path $config.login.connectionStringFile -InputObject $ss
        Write-Host (`
                "�ڑ��e�X�g���������܂����B`n" +
            "�ڑ�����{�[����p�ɈÍ������ĕۑ����܂��B`n" +
            "�p�X: $((Resolve-Path -Path $config.login.connectionStringFile).Path)`n" +
            "��������R�s�[���Ă����̒[���ł͓��삵�܂���B`n" +
            "����ȍ~�A���̃t�@�C�����Q�Ƃ��܂��B`n")
    }

    # mssql-scripter�����s
    foreach ($db in $config.databases) {
        $exportPath = [System.IO.Path]::Combine((Get-Location).Path, $config.mssqlScripter.exportDirectory , $db)
        if (Test-Path $exportPath) {
            Remove-Item -Path $exportPath -Recurse -Force
        }
        Write-Host (`
                "�f�[�^�x�[�X��`�o��`n" +
            "- �f�[�^�x�[�X:$db`n" +
            "- �ۑ���:$exportPath"
        )
        $argumentList = @(
            "--connection-string", "`"$connectionString;Initial Catalog=$db`"",
            "--file-path `"$exportPath`"")
        $config.mssqlScripter.args | ForEach-Object { $argumentList += [string]$_ }
        Start-Process `
            -FilePath $config.python.mssqlScripterPath `
            -WorkingDirectory $config.python.directoryPath `
            -ArgumentList $argumentList `
            -Wait `
            -RedirectStandardOutput $config.mssqlScripter.logName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "mssql-scripter ������ɏI�����܂���ł����B�A�J�E���g�Ȃǂ̌������m�F���Ă��������B"
        }
    }
}

Set-Location $PSScriptRoot
Write-Host @"
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DB��`�o��
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DB�̒�`���o�͂��܂��B

"@
try {
    Main
}
catch {
    Write-Host $_
}
pause