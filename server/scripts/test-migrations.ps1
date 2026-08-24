param(
    [string]$PostgresHost = "127.0.0.1",
    [int]$PostgresPort = 5432,
    [string]$PostgresUser = "postgres"
)

$ErrorActionPreference = "Stop"
$databaseName = "kairos_migration_test_" + [Guid]::NewGuid().ToString("N")
$serverRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Split-Path -Parent $serverRoot
$goCache = Join-Path $repositoryRoot ".gocache"
$databaseUrl = "postgres://${PostgresUser}@${PostgresHost}:${PostgresPort}/${databaseName}?sslmode=disable"

$createdb = (Get-Command createdb.exe -ErrorAction Stop).Source
$dropdb = (Get-Command dropdb.exe -ErrorAction Stop).Source

& $createdb -h $PostgresHost -p $PostgresPort -U $PostgresUser $databaseName
try {
    $env:KAIROS_DATABASE_URL = $databaseUrl
    $env:KAIROS_TEST_DATABASE_URL = $databaseUrl
    $env:KAIROS_SESSION_SECRET = "migration-test-session-secret-32-characters"
    $env:KAIROS_MIGRATIONS_DIR = Join-Path $serverRoot "migrations"
    $env:GOCACHE = $goCache

    Push-Location $serverRoot
    try {
        go run ./cmd/kairos-server migrate
        # These integration packages share the same temporary database. Run
        # them sequentially so global L3 bootstrap fixtures cannot race.
        go test -tags integration ./internal/store
        go test -tags integration ./internal/httpapi
    }
    finally {
        Pop-Location
    }
}
finally {
    & $dropdb -h $PostgresHost -p $PostgresPort -U $PostgresUser --if-exists --force $databaseName
}
