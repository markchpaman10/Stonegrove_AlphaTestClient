param([ValidateSet('Prepare','Commit')][string]$Mode,[Parameter(Mandatory=$true)][string]$Manifest,[string]$LocalArchive,[switch]$NoRelaunch)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$utf8=New-Object System.Text.UTF8Encoding($false)
$manifestPath=[IO.Path]::GetFullPath($Manifest)
$job=[IO.Path]::GetDirectoryName($manifestPath)
$statusPath=Join-Path $job 'status.json'
function Write-State($phase,$message){$json=@{phase=$phase;message=$message;helperPid=$PID}|ConvertTo-Json -Compress;[IO.File]::WriteAllText((Join-Path $job 'status.next'),$json,$utf8);Move-Item -LiteralPath (Join-Path $job 'status.next') -Destination $statusPath -Force}
function File-Hash($path){$stream=[IO.File]::OpenRead($path);$sha=[Security.Cryptography.SHA256]::Create();try{return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()}}
function Child-Path($base,$relative){
 $root=[IO.Path]::GetFullPath($base).TrimEnd('\')+'\';$path=[IO.Path]::GetFullPath((Join-Path $base $relative))
 if(-not $path.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Update path escaped its folder'}
 return $path
}
function Check-Reparse($path){$probe=$path;while($probe){if(Test-Path -LiteralPath $probe){if((Get-Item -LiteralPath $probe -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'An update path uses a link; extract the client into a normal folder'}};$parent=[IO.Path]::GetDirectoryName($probe);if($parent -eq $probe){break};$probe=$parent}}
function Allowed($relative){
 if($relative -match '^Documentation/.+\.(txt|md)$'){return $true}
 if($relative -match '^(game|assets|Runtime)/'){return $true}
 if($m.distribution -eq 'developer' -and $relative -match '^(ContentEditor|EditorShared|EventEditor|ItemEditor|LevelEditor|MonsterEditor|NPCEditor|QuestEditor)/'){return $true}
 if($relative -notmatch '/' -and ($relative -match '\.(lua|txt|md)$' -or $relative -in @('client_package.json','Update_Client.ps1','Play_Stonegrove.bat','Launch_Game.bat','Launch_Event_Editor.bat','Launch_Item_Editor.bat','Launch_Level_Editor.bat','Launch_Monster_Editor.bat','Launch_NPC_Editor.bat','Launch_Quest_Editor.bat'))){return $true}
 return $false
}
function Protected($relative){return $m.distribution -eq 'developer' -and $relative -in @('current.lua','item_data.lua','npc_data.lua','monster_data.lua','quest_data.lua','event_data.lua','content_data.lua')}
function Verify-Url($url){
 $u=[Uri]$url;if($u.Scheme -ne 'https' -or $u.UserInfo -or $u.Query -or $u.Fragment){throw 'Invalid update URL'}
 $prefix='https://github.com/'+$m.repository+'/releases/download/';$raw='https://raw.githubusercontent.com/'+$m.repository+'/'
 if(-not ($url.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or $url.StartsWith($raw,[StringComparison]::OrdinalIgnoreCase))){throw 'Update URL does not belong to the configured repository'}
}
function Check-Other-Processes {
 foreach($process in Get-Process -ErrorAction SilentlyContinue){
  if($process.Id -eq $m.parentPid -or $process.Id -eq $PID){continue}
  try{$exe=$process.Path;if($exe -and $exe.StartsWith($install+'\',[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($exe) -match '^lovec?\.exe$'){throw 'Close the other Stonegrove/editor windows, then retry the update'}}catch{if($_.Exception.Message -like 'Close the other*'){throw}}
 }
 if($m.distribution -eq 'developer'){
  foreach($process in Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'python3.exe'" -ErrorAction SilentlyContinue){
   if($process.CommandLine -notmatch 'server\.py'){continue}
   $related=$process.CommandLine.IndexOf($install,[StringComparison]::OrdinalIgnoreCase) -ge 0
   try{foreach($module in (Get-Process -Id $process.ProcessId -ErrorAction Stop).Modules){if($module.FileName.StartsWith($install+'\',[StringComparison]::OrdinalIgnoreCase)){$related=$true}}}catch{}
   if($related){throw 'Stop the account server running from this developer folder, then retry the client update'}
  }
 }
}
function Download($url,$file,$limit){
 Verify-Url $url
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 Add-Type -AssemblyName System.Net.Http
 $client=New-Object Net.Http.HttpClient
 $client.Timeout=[TimeSpan]::FromMinutes(5);$client.DefaultRequestHeaders.UserAgent.ParseAdd('Stonegrove-Updater/1.0')
 $response=$null;$stream=$null;$out=$null
 try{
  $response=$client.GetAsync($url,[Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult();$response.EnsureSuccessStatusCode()|Out-Null
  if($response.Content.Headers.ContentLength -gt $limit){throw 'Download is too large'}
  $stream=$response.Content.ReadAsStreamAsync().GetAwaiter().GetResult();$out=[IO.File]::Open($file,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  $buffer=New-Object byte[] 65536;$total=0;$nextStatus=[DateTime]::UtcNow
  while(($count=$stream.Read($buffer,0,$buffer.Length)) -gt 0){$total+=$count;if($total -gt $limit){throw 'Download exceeds the size limit'};$out.Write($buffer,0,$count);if([DateTime]::UtcNow -gt $nextStatus){Write-State 'downloading' ('Downloading update: '+[math]::Round($total/1MB,1)+' MB');$nextStatus=[DateTime]::UtcNow.AddSeconds(1)}}
 }finally{if($out){$out.Dispose()};if($stream){$stream.Dispose()};if($response){$response.Dispose()};$client.Dispose()}
}
$changed=New-Object System.Collections.Generic.List[object]
$rollbackFailed=$false
try {
 $m=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
 if($m.application -ne 'Stonegrove' -or $m.protocol -ne 1 -or $m.distribution -notin @('alpha','developer')){throw 'Invalid updater manifest'}
 if($m.repository -notmatch '^[\w.-]+/[\w.-]+$' -or $m.version -notmatch '^\d+\.\d+\.\d+\.\d+$' -or $m.currentVersion -notmatch '^\d+\.\d+\.\d+\.\d+$'){throw 'Invalid update version or repository'}
 if([Version]$m.version -le [Version]$m.currentVersion){throw 'Update must be newer than this client'}
 $install=[IO.Path]::GetFullPath($m.installRoot).TrimEnd('\')
 if(-not (Test-Path -LiteralPath (Join-Path $install 'main.lua') -PathType Leaf)){throw 'Extract the current client into a normal writable folder first'}
 Check-Reparse $install;Check-Reparse $job
 if($job.StartsWith($install+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Updater staging must be outside the installed client folder'}
 $stage=Child-Path $job 'stage';$backup=Child-Path $job 'backup';$archive=Child-Path $job 'download.zip';$planPath=Child-Path $job 'plan.json'
 if($Mode -eq 'Prepare') {
  Write-State 'downloading' 'Preparing the client update...'
  Check-Other-Processes
  $probe=Child-Path $install ('.stonegrove-update-write-'+[Guid]::NewGuid().ToString('N'))
  try{[IO.File]::WriteAllText($probe,'write-check',$utf8)}finally{if(Test-Path -LiteralPath $probe){Remove-Item -LiteralPath $probe}}
  if($LocalArchive){Copy-Item -LiteralPath ([IO.Path]::GetFullPath($LocalArchive)) -Destination $archive}else{Download $m.downloadUrl $archive 300MB}
  $expected=$m.sha256
  if(-not $expected){$checksum=Child-Path $job 'checksum.txt';Download $m.checksumUrl $checksum 4096;$content=Get-Content -LiteralPath $checksum -Raw;if($content -notmatch '^\s*([0-9a-fA-F]{64})(?:\s|$)'){throw 'Invalid SHA-256 checksum file'};$expected=$matches[1]}
  if($expected -notmatch '^[0-9a-fA-F]{64}$' -or (File-Hash $archive) -ne $expected){throw 'Downloaded ZIP failed SHA-256 verification; current client was not changed'}
  if($m.bytes -gt 0 -and (Get-Item -LiteralPath $archive).Length -ne $m.bytes){throw 'Downloaded ZIP size does not match the release'}
  Write-State 'validating' 'Verifying and extracting the update...'
  New-Item -ItemType Directory -Path $stage|Out-Null
  $zip=[IO.Compression.ZipFile]::OpenRead($archive);$files=New-Object System.Collections.Generic.List[string];$seen=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase);$total=0
  try{foreach($entry in $zip.Entries){
   $name=$entry.FullName.Replace('\','/');if($name.StartsWith('/') -or $name.Contains(':') -or ($name.Split('/') -contains '..') -or ($name.Split('/') -contains '.') -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000){throw 'ZIP contains an unsafe path or link'}
   if($name.EndsWith('/')){continue};if(-not $seen.Add($name)){throw 'ZIP contains duplicate file paths'}
   $total+=$entry.Length;if($total -gt 512MB -or $entry.Length -gt 200MB -or $seen.Count -gt 20000){throw 'ZIP exceeds extraction limits'}
   if(-not (Allowed $name)){continue}
   $dest=Child-Path $stage $name;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))|Out-Null
   [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$dest,$false);$files.Add($name)
  }}finally{$zip.Dispose()}
  $required=@('client_package.json','Update_Client.ps1','main.lua','conf.lua','game/launcher.lua','game/client_updates.lua','game/client_installer.lua','game/client_build.lua')
  if($m.distribution -eq 'alpha'){$required+=@('Runtime/love.exe','Runtime/love.dll','Runtime/lua51.dll')}
  foreach($name in $required){if(-not $files.Contains($name)){throw ('ZIP is missing required client file: '+$name)}}
  $package=Get-Content -LiteralPath (Join-Path $stage 'client_package.json') -Raw|ConvertFrom-Json
  if($package.application -ne 'Stonegrove' -or $package.format -ne 1 -or $package.version -ne $m.version -or $package.distribution -ne $m.distribution){throw 'ZIP version or distribution does not match this client'}
  $scriptVersion=Get-Content -LiteralPath (Join-Path $stage 'game/client_updates.lua') -Raw
  $versionPattern='version=[''"]'+[regex]::Escape($m.version)+'[''"]';if($scriptVersion -notmatch $versionPattern){throw 'ZIP client version does not match its manifest'}
  $hashes=@{};foreach($name in $files){$dest=Child-Path $install $name;Check-Reparse $dest;$hashes[$name]=(File-Hash (Child-Path $stage $name))}
  $parent=Get-Process -Id $m.parentPid -ErrorAction SilentlyContinue
  $plan=@{files=@($files.ToArray());hashes=$hashes;parentStarted=if($parent){$parent.StartTime.ToUniversalTime().Ticks.ToString()}else{''}}
  [IO.File]::WriteAllText($planPath,($plan|ConvertTo-Json -Depth 8 -Compress),$utf8)
  Write-State 'ready' 'Update verified. Restarting Stonegrove to install it...'
 } else {
  $plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json
  Write-State 'waiting' 'Waiting for Stonegrove to close...'
  $deadline=[DateTime]::UtcNow.AddSeconds(60)
  do{$parent=Get-Process -Id $m.parentPid -ErrorAction SilentlyContinue;$same=$parent -and $parent.StartTime.ToUniversalTime().Ticks.ToString() -eq $plan.parentStarted;if(-not $same){break};if([DateTime]::UtcNow -gt $deadline){throw 'Stonegrove did not close; current files were not changed'};Start-Sleep -Milliseconds 200}while($true)
  Check-Other-Processes
  $oldPackage=Join-Path $install 'client_package.json'
  if(Test-Path -LiteralPath $oldPackage){$old=Get-Content -LiteralPath $oldPackage -Raw|ConvertFrom-Json;if($old.version -ne $m.currentVersion){throw 'Installed client changed during the download; check for updates again'}}
  foreach($name in $plan.files){if(-not (Allowed $name)){throw 'Invalid install plan'};$file=Child-Path $stage $name;Check-Reparse $file;if((File-Hash $file) -ne $plan.hashes.$name){throw 'Staged file changed after verification'};Check-Reparse (Child-Path $install $name)}
  Write-State 'installing' 'Installing the verified client...'
  foreach($name in $plan.files){
   $dest=Child-Path $install $name;if((Protected $name) -and (Test-Path -LiteralPath $dest)){continue}
   $saved=Child-Path $backup $name;$existed=Test-Path -LiteralPath $dest
   if($existed){[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($saved))|Out-Null;Copy-Item -LiteralPath $dest -Destination $saved}
   [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))|Out-Null
   $changed.Add(@{name=$name;existed=$existed})
   Copy-Item -LiteralPath (Child-Path $stage $name) -Destination $dest -Force
  }
  Write-State 'complete' ('Updated to '+$m.version+'. Previous files are backed up.')
  if(-not $NoRelaunch){$exe=if($m.distribution -eq 'alpha'){Join-Path $install 'Runtime/love.exe'}else{$m.executable};if([IO.Path]::GetFileName($exe) -notmatch '^lovec?\.exe$' -or -not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Client installed, but LOVE could not be located for restart'};Start-Process -FilePath $exe -ArgumentList ('"'+$install+'"') -WorkingDirectory $install -WindowStyle Normal|Out-Null}
  # Delete only our checked staging folder and archive, never client/user data or backups.
  try{if(Test-Path -LiteralPath $stage){$verified=Child-Path $job 'stage';Check-Reparse $verified;Remove-Item -LiteralPath $verified -Recurse -Force}
  if(Test-Path -LiteralPath $archive){Remove-Item -LiteralPath (Child-Path $job 'download.zip')}}catch{}
 }
} catch {
 $failure=$_.Exception.Message
 for($index=$changed.Count-1;$index -ge 0;$index--){try{$entry=$changed[$index];$dest=Child-Path $install $entry.name;Check-Reparse $dest;if($entry.existed){Copy-Item -LiteralPath (Child-Path $backup $entry.name) -Destination $dest -Force}else{if(Test-Path -LiteralPath $dest){Remove-Item -LiteralPath $dest -Force}}}catch{$rollbackFailed=$true}}
 if($rollbackFailed){$failure+=' Some files could not be restored; recover the backup folder before launching.'}
 Write-State 'failed' $failure
 if($Mode -eq 'Commit' -and -not $NoRelaunch){try{$exe=$m.executable;if([IO.Path]::GetFileName($exe) -match '^lovec?\.exe$'){Start-Process -FilePath $exe -ArgumentList ('"'+$install+'"') -WorkingDirectory $install -WindowStyle Normal|Out-Null}}catch{}}
 exit 1
}
