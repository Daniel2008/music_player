param(
    [string]$OutputDirectory = 'F:\ai\music_player\build\verification\performance',
    [switch]$GpuOnly
)

$ErrorActionPreference = 'Stop'
$phaseFile = Join-Path $OutputDirectory 'phase.json'
$rows = [System.Collections.Generic.List[object]]::new()
$logicalProcessors = [Environment]::ProcessorCount
$deadline = [DateTime]::UtcNow.AddMinutes(9)
$previousCpu = $null
$previousTime = $null
$targetProcessId = $null
if ($GpuOnly) {
    while ([DateTime]::UtcNow -lt $deadline) {
        $phase = Get-Content -LiteralPath $phaseFile -Raw | ConvertFrom-Json
        if ($phase.phase -in @('done', 'failed')) { break }
        $prefix = "pid_$($phase.pid)_*"
        $counters = Get-Counter -Counter @(
            "\GPU Engine($prefix)\Utilization Percentage",
            "\GPU Process Memory($prefix)\Dedicated Usage",
            "\GPU Process Memory($prefix)\Shared Usage"
        ) -ErrorAction Stop
        $valid = @($counters.CounterSamples | Where-Object { $_.Status -eq 0 })
        $rows.Add([pscustomobject]@{
            utc = [DateTime]::UtcNow.ToString('o')
            phase = $phase.phase
            gpuBusiestEnginePercent = ($valid | Where-Object { $_.Path -like '*utilization percentage' } | Measure-Object CookedValue -Maximum).Maximum
            dedicatedMiB = ($valid | Where-Object { $_.Path -like '*dedicated usage' } | Measure-Object CookedValue -Sum).Sum / 1MB
            sharedMiB = ($valid | Where-Object { $_.Path -like '*shared usage' } | Measure-Object CookedValue -Sum).Sum / 1MB
        })
        $rows | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'gpu.csv') -NoTypeInformation -Encoding utf8
    }
    if ($rows.Count -lt 10) { throw 'Too few GPU samples.' }
    Write-Output "Collected $($rows.Count) GPU samples."
    return
}
$system = [ordered]@{
    startedUtc = [DateTime]::UtcNow.ToString('o')
    logicalProcessors = $logicalProcessors
    cpu = @(Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors)
    gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion)
    os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, TotalVisibleMemorySize, FreePhysicalMemory
    cpuPercentDefinition = 'CPU seconds delta / elapsed wall seconds / logical processors * 100'
}
$system | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'system.json') -Encoding utf8

try {
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $phaseFile) {
            try {
                $phase = Get-Content -LiteralPath $phaseFile -Raw | ConvertFrom-Json
            } catch {
                Start-Sleep -Milliseconds 100
                continue
            }
            if ($phase.phase -in @('done', 'failed')) {
                Write-Output "Measurement $($phase.phase); $($rows.Count) process samples."
                break
            }
            if ($null -eq $targetProcessId) {
                $targetProcessId = [int]$phase.pid
            }
            if ($targetProcessId -ne [int]$phase.pid) {
                throw 'The measured process changed during the run.'
            }
            $process = Get-Process -Id $targetProcessId -ErrorAction Stop
            $sampleTime = [DateTime]::UtcNow
            $cpuSeconds = $process.TotalProcessorTime.TotalSeconds
            if ($null -ne $previousCpu) {
                $elapsed = ($sampleTime - $previousTime).TotalSeconds
                if ($elapsed -le 0 -or $cpuSeconds -lt $previousCpu) {
                    throw 'Non-monotonic process sample.'
                }
                $corePercent = 100 * ($cpuSeconds - $previousCpu) / $elapsed
                $rows.Add([pscustomobject]@{
                    utc = $sampleTime.ToString('o')
                    phase = $phase.phase
                    pid = $targetProcessId
                    elapsedSeconds = $elapsed
                    cpuSeconds = $cpuSeconds - $previousCpu
                    cpuMachinePercent = $corePercent / $logicalProcessors
                    cpuOneCorePercent = $corePercent
                    workingSetMiB = $process.WorkingSet64 / 1MB
                    privateMiB = $process.PrivateMemorySize64 / 1MB
                    handles = $process.HandleCount
                    threads = $process.Threads.Count
                })
            }
            $previousCpu = $cpuSeconds
            $previousTime = $sampleTime
        }
        Start-Sleep -Seconds 1
    }
} finally {
    $rows | Export-Csv -LiteralPath (Join-Path $OutputDirectory 'process.csv') -NoTypeInformation -Encoding utf8
}
if ($rows.Count -lt 10) {
    throw "Only $($rows.Count) samples collected."
}
