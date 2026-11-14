# Every test at once, each with a time limit. Prints pass or fail per test and the total time.
#   powershell -File tests/run_all.ps1
param([string]$godot = "C:\Users\Adrian\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe")
$root = Split-Path $PSScriptRoot -Parent
$logs = Join-Path $env:TEMP "tagrush-tests"
New-Item -ItemType Directory -Force $logs | Out-Null
$clock = [Diagnostics.Stopwatch]::StartNew()
$base = @('--headless', '--path', $root)

function Start-Test($name, $testArgs) {
    $p = Start-Process -FilePath $godot -ArgumentList ($base + $testArgs) -NoNewWindow -PassThru `
        -RedirectStandardOutput "$logs\$name.out" -RedirectStandardError "$logs\$name.err"
    $null = $p.Handle  # keeps ExitCode readable after it ends
    return @{ name = $name; proc = $p }
}

$tests = @(
    (Start-Test "checks" @('res://tests/checks.tscn'))
    (Start-Test "city" @('res://tests/city.tscn'))
    (Start-Test "map_checks" @('res://tests/map_checks.tscn'))
    (Start-Test "movement" @('res://tests/movement.tscn', '--', '--host', '--port=27205', '--autostart=1', '--size=small'))
    (Start-Test "two_player" @('res://tests/two_player.tscn', '--', '--host', '--port=27199', '--name=Same'))
    (Start-Test "three_host" @('res://tests/three_player.tscn', '--', '--host', '--port=27197', '--name=H'))
)
$port = 27210
foreach ($size in "classic", "small", "medium", "large") {
    $tests += Start-Test "rounds_$size" @('res://tests/rounds.tscn', '--', '--host', "--port=$port", '--autostart=1', "--size=$size")
    $port += 1
}
Start-Sleep -Milliseconds 800  # the hosts are listening
$helpers = @(
    (Start-Test "two_join" @('res://tests/two_player.tscn', '--', '--join=127.0.0.1:27199', '--name=Same'))
    (Start-Test "three_b" @('res://tests/three_player.tscn', '--', '--join=127.0.0.1:27197', '--name=B'))
)
Start-Sleep -Milliseconds 400
$tests += Start-Test "three_player" @('res://tests/three_player.tscn', '--', '--join=127.0.0.1:27197', '--name=A')

$failed = 0
foreach ($t in $tests) {
    if ($t.name -eq "three_host") { continue }
    $left = [int][Math]::Max(1000, 60000 - $clock.ElapsedMilliseconds)
    if (-not $t.proc.WaitForExit($left)) {
        $t.proc.Kill()
        "TIMED OUT  $($t.name)"
        $failed += 1
        continue
    }
    if ($t.proc.ExitCode -eq 0) {
        "pass       $($t.name)"
    } else {
        "FAILED     $($t.name)"
        Get-Content "$logs\$($t.name).out", "$logs\$($t.name).err" | Where-Object { $_ -match 'FAIL|SCRIPT ERROR' } | Select-Object -First 5
        $failed += 1
    }
}
foreach ($t in ($helpers + ($tests | Where-Object { $_.name -eq "three_host" }))) {
    if (-not $t.proc.HasExited) { $t.proc.Kill() }
}
"{0} failed, {1:n1} s" -f $failed, $clock.Elapsed.TotalSeconds
exit $failed
