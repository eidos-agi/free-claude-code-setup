$ErrorActionPreference = 'Continue'
$results = New-Object System.Collections.ArrayList
$num = 0
function Add-Result($name, $status, $detail) {
    $script:num++
    [void]$script:results.Add([pscustomobject]@{ '#'=$script:num; Test=$name; Status=$status; Detail=$detail })
}

# Capture pre-state
$credsBefore = (Get-Item "C:\Users\Shadow\.claude\.credentials.json" -ErrorAction SilentlyContinue).LastWriteTime

# === STATIC INTEGRITY ===
$p = "C:\Users\Shadow\AppData\Roaming\npm\claude.cmd"
Add-Result "Windows claude.cmd exists" $(if (Test-Path $p) { 'PASS' } else { 'FAIL' }) $p

$p = "C:\Users\Shadow\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe"
$ver = (Get-Item $p -ErrorAction SilentlyContinue).VersionInfo.FileVersion
Add-Result "claude.exe v2.1.120" $(if ($ver -like "2.1.120*") { 'PASS' } else { 'FAIL' }) $ver

$p = "C:\Users\Shadow\bin\claude-nim.bat"
Add-Result "Windows claude-nim.bat shim exists" $(if (Test-Path $p) { 'PASS' } else { 'FAIL' }) $p

$bytes = [System.IO.File]::ReadAllBytes("C:\Users\Shadow\bin\claude-nim.bat")
$lf = ($bytes | Where-Object { $_ -eq 0x0A }).Count
$crlf = 0; for ($i=1; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -eq 0x0A -and $bytes[$i-1] -eq 0x0D) { $crlf++ } }
Add-Result "Windows claude-nim.bat is CRLF" $(if ($crlf -eq $lf -and $lf -gt 0) { 'PASS' } else { 'FAIL' }) "CRLF=$crlf LF=$lf"

$content = Get-Content "C:\Users\Shadow\bin\claude-nim.bat" -Raw
Add-Result "Windows shim points at /home/dshanklin UNC" $(if ($content -match 'home\\dshanklin\\repos') { 'PASS' } else { 'FAIL' }) ($content -split "`n" | Select-Object -Last 2 | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ' / '

$bytes = [System.IO.File]::ReadAllBytes("C:\Users\Shadow\bin\stop-nim-proxy.bat")
$lf = ($bytes | Where-Object { $_ -eq 0x0A }).Count
$crlf = 0; for ($i=1; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -eq 0x0A -and $bytes[$i-1] -eq 0x0D) { $crlf++ } }
Add-Result "Windows stop-nim-proxy.bat is CRLF" $(if ($crlf -eq $lf -and $lf -gt 0) { 'PASS' } else { 'FAIL' }) "CRLF=$crlf LF=$lf"

$f = "\\wsl$\Ubuntu\home\dshanklin\repos\free-claude-code-setup\bin\claude-nim.bat"
$bytes = [System.IO.File]::ReadAllBytes($f)
$lf = ($bytes | Where-Object { $_ -eq 0x0A }).Count
$crlf = 0; for ($i=1; $i -lt $bytes.Length; $i++) { if ($bytes[$i] -eq 0x0A -and $bytes[$i-1] -eq 0x0D) { $crlf++ } }
Add-Result "Canonical bin/claude-nim.bat is CRLF" $(if ($crlf -eq $lf -and $lf -gt 0) { 'PASS' } else { 'FAIL' }) "CRLF=$crlf LF=$lf"

# Canonical sh script via WSL probe
$shCheck = wsl -d Ubuntu -u root -- bash -c 'test -x /home/dshanklin/repos/free-claude-code-setup/bin/claude-nim && echo OK || echo NO'
Add-Result "Canonical bin/claude-nim is executable" $(if ($shCheck -match 'OK') { 'PASS' } else { 'FAIL' }) $shCheck

$symlink = wsl -d Ubuntu -u root -- bash -c 'readlink -f /usr/local/bin/claude-nim 2>/dev/null'
Add-Result "WSL /usr/local/bin/claude-nim symlink resolves" $(if ($symlink -match 'claude-nim$' -and $symlink -notmatch '^$') { 'PASS' } else { 'FAIL' }) $symlink

$ga = wsl -d Ubuntu -u root -- bash -c 'grep eol=crlf /home/dshanklin/repos/free-claude-code-setup/.gitattributes 2>/dev/null'
Add-Result ".gitattributes pins .bat/.cmd to CRLF" $(if ($ga -match 'eol=crlf') { 'PASS' } else { 'FAIL' }) ($ga -join ' / ')

$envCheck = wsl -d Ubuntu -u root -- bash -c 'test -f /home/dshanklin/repos/free-claude-code-setup/proxy/.env && stat -c %a /home/dshanklin/repos/free-claude-code-setup/proxy/.env'
Add-Result "proxy/.env exists" $(if ($envCheck -match '^[0-9]+$') { 'PASS' } else { 'FAIL' }) "perms=$envCheck"

$keyCheck = wsl -d Ubuntu -u root -- bash -c 'grep -E "^(NVIDIA_NIM_API_KEY|NVIDIA_API_KEY|NIM_API_KEY)=nvapi-" /home/dshanklin/repos/free-claude-code-setup/proxy/.env 2>/dev/null | head -1 | sed "s/=.*/=<set>/"'
Add-Result "NIM/NVIDIA API key is set" $(if ($keyCheck -match '=<set>') { 'PASS' } else { 'FAIL' }) $keyCheck

# === PATH ===
$out = & cmd /c "where claude" 2>&1 | Out-String
Add-Result "Windows: where claude resolves" $(if ($out -match 'claude\.cmd') { 'PASS' } else { 'FAIL' }) ($out -split "`n" | Select-Object -First 1).Trim()

$out = & cmd /c "where claude-nim" 2>&1 | Out-String
Add-Result "Windows: where claude-nim resolves" $(if ($out -match 'claude-nim\.bat') { 'PASS' } else { 'FAIL' }) ($out -split "`n" | Select-Object -First 1).Trim()

$out = wsl -d Ubuntu -- bash -c 'which claude' 2>&1
Add-Result "WSL: which claude (interop)" $(if ($out -match '/mnt/c/.*claude') { 'PASS' } else { 'FAIL' }) ($out | Select-Object -First 1)

# === claude (subscription) — fresh shell to avoid env contamination ===
$out = & cmd /c "claude --version" 2>&1 | Out-String
$v = $out.Trim()
Add-Result "claude --version prints 2.1.120" $(if ($v -match '2\.1\.120') { 'PASS' } else { 'FAIL' }) $v

try {
    $creds = Get-Content "C:\Users\Shadow\.claude\.credentials.json" -Raw | ConvertFrom-Json
    Add-Result ".credentials.json is valid JSON" 'PASS' "parsed"
    Add-Result "subscriptionType is 'max'" $(if ($creds.claudeAiOauth.subscriptionType -eq 'max') { 'PASS' } else { 'FAIL' }) $creds.claudeAiOauth.subscriptionType
    $exp = (Get-Date "1970-01-01T00:00:00Z").AddMilliseconds($creds.claudeAiOauth.expiresAt)
    $secsLeft = [math]::Round((New-TimeSpan -Start (Get-Date) -End $exp).TotalSeconds)
    Add-Result "OAuth token not expired" $(if ($secsLeft -gt 0) { 'PASS' } else { 'FAIL' }) "expires in ${secsLeft}s ($($exp.ToUniversalTime().ToString('o')))"
    Add-Result "OAuth token has refreshToken" $(if ($creds.claudeAiOauth.refreshToken) { 'PASS' } else { 'FAIL' }) "refreshToken length: $($creds.claudeAiOauth.refreshToken.Length)"
} catch {
    Add-Result ".credentials.json is valid JSON" 'FAIL' $_.Exception.Message
    Add-Result "subscriptionType is 'max'" 'SKIP' "creds unparseable"
    Add-Result "OAuth token not expired" 'SKIP' "creds unparseable"
    Add-Result "OAuth token has refreshToken" 'SKIP' "creds unparseable"
}

$credsAfterPlain = (Get-Item "C:\Users\Shadow\.claude\.credentials.json").LastWriteTime
Add-Result "Plain claude --version doesn't touch creds" $(if ($credsBefore -eq $credsAfterPlain) { 'PASS' } else { 'FAIL' }) "before=$($credsBefore.ToString('o')) after=$($credsAfterPlain.ToString('o'))"

# === claude-nim ===
$nimStart = Get-Date
$out = & cmd /c '"C:\Users\Shadow\bin\claude-nim.bat" --version' 2>&1 | Out-String
$nimElapsed = ((Get-Date) - $nimStart).TotalSeconds
Add-Result "claude-nim --version exits clean" $(if ($out -match '2\.1\.120') { 'PASS' } else { 'FAIL' }) "${nimElapsed}s; output=$($out -replace '`r?`n', ' | ')"

$credsAfterNim = (Get-Item "C:\Users\Shadow\.claude\.credentials.json").LastWriteTime
Add-Result "claude-nim doesn't touch subscription creds" $(if ($credsBefore -eq $credsAfterNim) { 'PASS' } else { 'FAIL' }) "before=$($credsBefore.ToString('o')) after=$($credsAfterNim.ToString('o'))"

$isoProfile = "C:\Users\Shadow\AppData\Local\claude-nim-profile"
Add-Result "Isolated NIM profile dir exists" $(if (Test-Path $isoProfile) { 'PASS' } else { 'FAIL' }) $isoProfile

$isoCreds = "$isoProfile\.claude\.credentials.json"
Add-Result "No OAuth creds leak into NIM profile" $(if (-not (Test-Path $isoCreds)) { 'PASS' } else { 'FAIL' }) $isoCreds

# === proxy state ===
$tcp = New-Object System.Net.Sockets.TcpClient
$async = $tcp.BeginConnect("127.0.0.1", 8082, $null, $null)
$wait = $async.AsyncWaitHandle.WaitOne(2000)
Add-Result ":8082 listening after claude-nim" $(if ($wait -and $tcp.Connected) { 'PASS' } else { 'FAIL' }) "tcp_connected=$($tcp.Connected)"
$tcp.Close()

try {
    Invoke-WebRequest -Uri "http://127.0.0.1:8082/" -TimeoutSec 3 -UseBasicParsing | Out-Null
    Add-Result "Proxy GET / requires auth" 'FAIL' "200 (should be 401)"
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    Add-Result "Proxy GET / requires auth" $(if ($code -eq 401) { 'PASS' } else { 'FAIL' }) "HTTP $code"
}

# Real end-to-end NIM completion via proxy
$body = '{"model":"claude-3-5-sonnet-20241022","max_tokens":40,"messages":[{"role":"user","content":"Reply with just the word PING and nothing else."}]}'
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:8082/v1/messages" -Method POST `
        -Headers @{ "x-api-key"="freecc"; "anthropic-version"="2023-06-01"; "Content-Type"="application/json" } `
        -Body $body -TimeoutSec 30 -UseBasicParsing
    $j = $resp.Content | ConvertFrom-Json
    $txt = ($j.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
    Add-Result "Proxy /v1/messages returns 200 (auth=x-api-key)" $(if ($resp.StatusCode -eq 200) { 'PASS' } else { 'FAIL' }) "HTTP $($resp.StatusCode); content=$($txt -replace "`n",' ')"
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code -eq 401 -or $code -eq 403) {
        # Fallback: try Authorization Bearer
        try {
            $resp2 = Invoke-WebRequest -Uri "http://127.0.0.1:8082/v1/messages" -Method POST `
                -Headers @{ "Authorization"="Bearer freecc"; "anthropic-version"="2023-06-01"; "Content-Type"="application/json" } `
                -Body $body -TimeoutSec 30 -UseBasicParsing
            $j2 = $resp2.Content | ConvertFrom-Json
            $txt2 = ($j2.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
            Add-Result "Proxy /v1/messages returns 200 (auth=Bearer)" $(if ($resp2.StatusCode -eq 200) { 'PASS' } else { 'FAIL' }) "HTTP $($resp2.StatusCode); content=$($txt2 -replace "`n",' ')"
        } catch {
            Add-Result "Proxy /v1/messages POST" 'FAIL' ("x-api-key=" + $code + "; Bearer=" + ($_.Exception.Message -replace "`r?`n",' '))
        }
    } else {
        Add-Result "Proxy /v1/messages POST" 'FAIL' ($code.ToString() + " - " + ($_.Exception.Message -replace "`r?`n",' '))
    }
}

# uvicorn process running
$uvi = wsl -d Ubuntu -u root -- bash -c 'pgrep -af uvicorn 2>/dev/null | head -1'
Add-Result "uvicorn running in WSL" $(if ($uvi -match 'uvicorn') { 'PASS' } else { 'FAIL' }) ($uvi -replace '^\d+\s+','')

$logSize = wsl -d Ubuntu -u root -- bash -c 'wc -c < /home/dshanklin/.cache/nim-proxy.log 2>/dev/null'
Add-Result "Proxy log file exists/non-empty" $(if ([int]$logSize -gt 0) { 'PASS' } else { 'FAIL' }) "${logSize} bytes"

# === WSL state ===
$wstat = (wsl --status 2>&1 | Out-String) -replace "`0",''
Add-Result "WSL Ubuntu running (wsl --status)" $(if ($wstat -match 'U.*b.*u.*n.*t.*u' -or $wstat -match 'Default') { 'PASS' } else { 'FAIL' }) ($wstat -split "`n" | Select-Object -First 1).Trim()

$dns = wsl -d Ubuntu -u root -- bash -c 'getent hosts integrate.api.nvidia.com 2>&1 | head -1'
Add-Result "WSL DNS resolves NIM endpoint" $(if ($dns -match 'integrate\.api\.nvidia\.com') { 'PASS' } else { 'FAIL' }) $dns

# Concurrent invocation - second claude-nim should reuse
$out2 = & cmd /c '"C:\Users\Shadow\bin\claude-nim.bat" --version' 2>&1 | Out-String
Add-Result "Second claude-nim reuses proxy" $(if ($out2 -match 'already listening') { 'PASS' } else { 'FAIL' }) (($out2 -split "`r?`n") | Where-Object { $_ -match 'claude-nim' } | Select-Object -First 1)

# WSL claude-nim invocation as dshanklin
$wslNim = wsl -d Ubuntu -- bash -lc 'claude-nim --version 2>&1 | tail -3' 2>&1 | Out-String
Add-Result "WSL: claude-nim --version (as dshanklin)" $(if ($wslNim -match '2\.1\.\d+') { 'PASS' } else { 'FAIL' }) ($wslNim -replace "`r?`n",' | ' -replace '\s+',' ').Trim()

# WSL Linux-native claude tests
$wslLinux = wsl -d Ubuntu -- bash -c 'claude --version 2>&1' | Out-String
Add-Result "WSL Linux-native claude --version (any shell)" $(if ($wslLinux -match '2\.1\.81') { 'PASS' } else { 'FAIL' }) ($wslLinux -replace "`r?`n",' ').Trim()

$nodeLink = wsl -d Ubuntu -- bash -c 'readlink -f /usr/local/bin/node 2>/dev/null' | Out-String
Add-Result "/usr/local/bin/node symlink resolves" $(if ($nodeLink -match 'node$' -and $nodeLink -notmatch '^$') { 'PASS' } else { 'FAIL' }) ($nodeLink.Trim())

$claudeLink = wsl -d Ubuntu -- bash -c 'readlink -f /usr/local/bin/claude 2>/dev/null' | Out-String
Add-Result "/usr/local/bin/claude symlink resolves to nvm" $(if ($claudeLink -match 'nvm/versions/node.*claude') { 'PASS' } else { 'FAIL' }) ($claudeLink.Trim())

$dshOwn = wsl -d Ubuntu -u root -- bash -c 'stat -c "%U:%G" /home/dshanklin/.claude' | Out-String
Add-Result "/home/dshanklin/.claude owned by dshanklin" $(if ($dshOwn -match 'dshanklin:dshanklin') { 'PASS' } else { 'FAIL' }) ($dshOwn.Trim())

# Trilogy MCP tools installed
$tri = wsl -d Ubuntu -- bash -lc 'uv tool list 2>/dev/null | grep -E "^(research-md|visionlog-md|ike-md)" | wc -l'
Add-Result "Trilogy (research-md/visionlog-md/ike-md) installed" $(if ($tri.Trim() -eq '3') { 'PASS' } else { 'FAIL' }) "$tri tools found"

# Memory file integrity
$mem = "C:\Users\Shadow\.claude\projects\C--Users-Shadow\memory\reference_nim_setup.md"
$memContent = Get-Content $mem -Raw -ErrorAction SilentlyContinue
Add-Result "Memory mentions /home/dshanklin path" $(if ($memContent -match 'home/dshanklin') { 'PASS' } else { 'FAIL' }) "file exists: $(Test-Path $mem)"
Add-Result "Memory mentions CRLF trap" $(if ($memContent -match 'CRLF') { 'PASS' } else { 'FAIL' }) "trap doc present"

# Final post-state check
$credsFinal = (Get-Item "C:\Users\Shadow\.claude\.credentials.json").LastWriteTime
Add-Result "Subscription creds intact through all tests" $(if ($credsBefore -eq $credsFinal) { 'PASS' } else { 'FAIL' }) "before=$($credsBefore.ToString('o')) final=$($credsFinal.ToString('o'))"

# Summary
$pass = ($results | Where-Object { $_.Status -eq 'PASS' }).Count
$fail = ($results | Where-Object { $_.Status -eq 'FAIL' }).Count
$skip = ($results | Where-Object { $_.Status -eq 'SKIP' }).Count
$results | Format-Table -AutoSize -Wrap
"`n=== SUMMARY: $pass PASS, $fail FAIL, $skip SKIP / total $($results.Count) ==="
