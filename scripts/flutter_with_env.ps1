param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $workspaceRoot '.env'
$clientAssetDirectory = Join-Path $workspaceRoot 'assets/config'
$clientAssetPath = Join-Path $clientAssetDirectory 'client.env'

if (-not (Test-Path $envPath)) {
    throw 'File .env tidak ditemukan. Salin .env.example menjadi .env lalu isi konfigurasi publik Supabase.'
}

$clientValues = @{}
$allowedClientKeys = @(
    'SUPABASE_URL',
    'SUPABASE_PUBLISHABLE_KEY',
    'GOOGLE_SERVER_CLIENT_ID',
    'GOOGLE_IOS_CLIENT_ID'
)
foreach ($line in Get-Content $envPath) {
    $trimmedLine = $line.Trim()
    if (-not $trimmedLine -or $trimmedLine.StartsWith('#')) {
        continue
    }

    $separatorIndex = $trimmedLine.IndexOf('=')
    if ($separatorIndex -lt 1) {
        continue
    }

    $name = $trimmedLine.Substring(0, $separatorIndex).Trim()
    if ($name -notin $allowedClientKeys) {
        continue
    }

    $value = $trimmedLine.Substring($separatorIndex + 1).Trim()
    if ($value.Length -ge 2 -and
        (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'")))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    $clientValues[$name] = $value
}

if (-not $clientValues['SUPABASE_URL'] -or
    -not $clientValues['SUPABASE_PUBLISHABLE_KEY']) {
    throw '.env harus berisi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY untuk menjalankan atau membangun aplikasi.'
}
if ($clientValues['SUPABASE_URL'] -notmatch '^https://') {
    throw 'SUPABASE_URL harus menggunakan HTTPS.'
}

[System.IO.Directory]::CreateDirectory($clientAssetDirectory) | Out-Null
$clientAssetLines = @(
    "SUPABASE_URL=$($clientValues['SUPABASE_URL'])",
    "SUPABASE_PUBLISHABLE_KEY=$($clientValues['SUPABASE_PUBLISHABLE_KEY'])",
    "GOOGLE_SERVER_CLIENT_ID=$($clientValues['GOOGLE_SERVER_CLIENT_ID'])",
    "GOOGLE_IOS_CLIENT_ID=$($clientValues['GOOGLE_IOS_CLIENT_ID'])"
)
[System.IO.File]::WriteAllLines(
    $clientAssetPath,
    $clientAssetLines,
    [System.Text.UTF8Encoding]::new($false)
)

$arguments = @($FlutterArguments)
Push-Location $workspaceRoot
try {
    & flutter @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
