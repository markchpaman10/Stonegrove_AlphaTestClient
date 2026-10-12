local I={}
local J=require('game.json')
function I.environment()
 local ffi=require('ffi');if ffi.os~='Windows'then error('Automatic installation currently requires Windows')end
 ffi.cdef[[unsigned long GetCurrentProcessId(void);unsigned long GetModuleFileNameW(void*,unsigned short*,unsigned long);int WideCharToMultiByte(unsigned int,unsigned long,const unsigned short*,int,char*,int,const char*,int*);int MultiByteToWideChar(unsigned int,unsigned long,const char*,int,unsigned short*,int);void* ShellExecuteW(void*,const unsigned short*,const unsigned short*,const unsigned short*,const unsigned short*,int);]]
 local k=ffi.load('kernel32');local b=ffi.new('unsigned short[32768]');local len=k.GetModuleFileNameW(nil,b,32768);assert(len>0,'Cannot locate running client')
 local n=k.WideCharToMultiByte(65001,0,b,len,nil,0,nil,nil);local out=ffi.new('char[?]',n);k.WideCharToMultiByte(65001,0,b,len,out,n,nil,nil)
 return{pid=tonumber(k.GetCurrentProcessId()),executable=ffi.string(out,n)}
end
function I.spawn(mode,helper,manifest)
 local ffi=require('ffi');local k=ffi.load('kernel32')
 local function wide(s)local n=k.MultiByteToWideChar(65001,0,s,#s,nil,0);local b=ffi.new('unsigned short[?]',n+1);k.MultiByteToWideChar(65001,0,s,#s,b,n);return b end
 local function quote(s)assert(not s:find('["\r\n]'),'Invalid update path');return '"'..s..'"'end
 local args='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File '..quote(helper)..' -Mode '..mode..' -Manifest '..quote(manifest)
 local result=ffi.load('shell32').ShellExecuteW(nil,wide('open'),wide((os.getenv('SystemRoot')or'C:\\Windows')..'\\System32\\WindowsPowerShell\\v1.0\\powershell.exe'),wide(args),nil,0)
 return tonumber(ffi.cast('intptr_t',result))>32
end
function I.start(update)
 if I.job then return false end
 local ok,why=pcall(function()
  local env=I.environment();local root=love.filesystem.getSource();assert(love.filesystem.getInfo('client_package.json'),'Extract this new client first to enable automatic installation')
  assert(update.downloadUrl,'This release is missing its matching client ZIP')
  local version=update.latest:gsub('^v','');local relative='client-updates/job-'..tostring(os.time())..'-'..tostring(env.pid)..'-'..tostring(math.random(100000,999999))
  assert(love.filesystem.createDirectory(relative),'Cannot create update staging folder')
  local helper=assert(love.filesystem.read('Update_Client.ps1'),'Updater helper is missing')
  assert(love.filesystem.write(relative..'/helper.ps1',helper),'Cannot stage updater helper')
  local jobRoot=love.filesystem.getSaveDirectory()..'/'..relative
  local manifest={application='Stonegrove',protocol=1,distribution=require('game.client_build').distribution,currentVersion=update.version,version=version,repository=update.repo,downloadUrl=update.downloadUrl,checksumUrl=update.checksumUrl,sha256=update.sha256,bytes=update.bytes,installRoot=root,executable=env.executable,parentPid=env.pid}
  assert(love.filesystem.write(relative..'/manifest.json',J.encode(manifest)),'Cannot write update manifest')
  assert(love.filesystem.write('client_update_last.json',J.encode({job=relative,installRoot=root})),'Cannot record update job')
  assert(I.spawn('Prepare',jobRoot..'/helper.ps1',jobRoot..'/manifest.json'),'Windows could not start the update helper')
  I.job={relative=relative,root=jobRoot,started=love.timer.getTime(),phase='preparing'}
  update.state='installing';update.message='Downloading and verifying the latest client...'
 end)
 if not ok then update.state='failed';update.message='Update could not start: '..tostring(why);return false end
 return true
end
function I.poll(update)
 local job=I.job;if not job then return end
 local text=love.filesystem.read(job.relative..'/status.json');local status
 if text then local ok,d=pcall(J.decode,text);if ok then status=d end end
 if status then
  update.message=tostring(status.message or'Preparing the update...');job.phase=status.phase
  if status.phase=='failed'then update.state='failed';I.job=nil;return end
  if status.phase=='ready'and not job.committing then
   local ok,result=pcall(I.spawn,'Commit',job.root..'/helper.ps1',job.root..'/manifest.json')
   if not ok or not result then update.state='failed';update.message='Could not start installation. Your current client is unchanged.';I.job=nil;return end
   job.committing=true;update.message='Installing update and restarting Stonegrove...';love.event.quit();return
  end
 end
 if not job.committing and love.timer.getTime()-job.started>420 then update.state='failed';update.message='Update download timed out. Current client files are unchanged; check and retry.';I.job=nil end
end
function I.previousFailure()
 local text=love.filesystem.read('client_update_last.json');if not text then return end
 local ok,last=pcall(J.decode,text);if not ok or last.installRoot~=love.filesystem.getSource()or type(last.job)~='string'or not last.job:match('^client%-updates/job%-%d+%-%d+%-%d+$')then return end
 text=love.filesystem.read(last.job..'/status.json');if text then local good,state=pcall(J.decode,text);if good and state.phase=='failed'then return 'Previous update failed: '..tostring(state.message)..' Check for updates to retry.'end end
end
return I
