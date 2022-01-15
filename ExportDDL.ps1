using namespace System.Runtime.InteropServices;
using namespace System.Data.SqlClient

# 接続文字列の確認
# 接続のOpenができればTrueを返す。ログインユーザー自体の権限はチェックできないので注意
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
    # 環境変数に接続文字列を設定
    $ConfigFileName = "ExportDDL.Config.json"
    $config = Get-Content $ConfigFileName | ConvertFrom-Json
    if (-not (Test-Path -path $config.python.directoryPath)) {
        Throw "[エラー]pythonがインストールされていません。終了します。"
    }

    if (Test-Path -Path $config.login.connectionStringFile) {
        # 既存の接続文字列ファイルから接続文字列を読み込む
        Write-Host "保存された接続情報からDB定義を出力します。"

        $ss = Import-Clixml -Path $config.login.connectionStringFile
        $connectionString = [Marshal]::PtrToStringBSTR([Marshal]::SecureStringToBSTR($ss));
        if (-not (IsConnectionStringValid($connectionString))) {
            Remove-Item -Path $config.login.connectionStringFile -Force
            throw `
                "[エラー]保存された接続情報で接続に失敗しました。`n" +
            "保存された接続情報ファイルを削除しました。`n" +
            "パス:$FilePath`n" +
            "再度実行して下さい。`n"
        }
    }
    else {
        # 新規に接続文字列を作る。
        Write-Host (`
                "下記の設定で接続します。`n" +
            "- サーバー:$($config.login.server)`n" +
            "- ユーザー:$($config.login.userId)`n" +
            "※他の設定で接続したい場合は設定ファイル[$ConfigFileName]を修正して下さい。`n" +
            "`n" +
            "パスワードを入力して下さい。`n" +
            "`n")

        [SecureString]$ssPass = Read-Host "パスワード" -AsSecureString
        [SqlConnectionStringBuilder]$builder = New-Object SqlConnectionStringBuilder -Property @{
            DataSource = $config.login.server
            UserID     = $config.login.userId
            Password   = [Marshal]::PtrToStringBSTR([Marshal]::SecureStringToBSTR($ssPass))
        }

        if (-not (IsConnectionStringValid($builder.ConnectionString))) {
            throw `
                "[エラー]接続に失敗しました。`n" +
            "パスワードが間違っている可能性があります。`n" +
            "確認して再度実行して下さい。`n"
        }

        # 接続成功した接続文字列の暗号化した保存
        $ss = ConvertTo-SecureString $builder.ConnectionString -AsPlainText -Force
        Export-Clixml -Path $config.login.connectionStringFile -InputObject $ss
        Write-Host (`
                "接続テストが成功しました。`n" +
            "接続情報を本端末専用に暗号化して保存します。`n" +
            "パス: $((Resolve-Path -Path $config.login.connectionStringFile).Path)`n" +
            "※これをコピーしても他の端末では動作しません。`n" +
            "次回以降、このファイルを参照します。`n")
    }

    # mssql-scripterを実行
    foreach ($db in $config.databases) {
        $exportPath = [System.IO.Path]::Combine((Get-Location).Path, $config.mssqlScripter.exportDirectory , $db)
        if (Test-Path $exportPath) {
            Remove-Item -Path $exportPath -Recurse -Force
        }
        Write-Host (`
                "データベース定義出力`n" +
            "- データベース:$db`n" +
            "- 保存先:$exportPath"
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
            Write-Host "mssql-scripter が正常に終了しませんでした。アカウントなどの権限を確認してください。"
        }
    }
}

Set-Location $PSScriptRoot
Write-Host @"
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DB定義出力
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
DBの定義を出力します。

"@
try {
    Main
}
catch {
    Write-Host $_
}
pause