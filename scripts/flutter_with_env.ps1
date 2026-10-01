param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)

$ErrorActionPreference = 'Stop'
$workspaceRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $workspaceRoot '.env'

if (-not (Test-Path $envPath)) {
    throw 'File .env tidak ditemukan. Salin .env.example menjadi .env lalu isi konfigurasi publik Supabase.'
}

$defines = [System.Collections.Generic.List[string]]::new()
$allowedClientKeys = @('SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY')
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
    if ($value) {
        $defines.Add("--dart-define=$name=$value")
    }
}

$arguments = @($FlutterArguments) + $defines.ToArray()
Push-Location $workspaceRoot
try {
    & flutter @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
