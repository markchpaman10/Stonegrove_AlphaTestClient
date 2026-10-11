local U={version='0.3.63.48',state='idle',message='',serial=0}
function U.versionParts(v)
 if type(v)~='string'then return end
 local a,b,c,d=v:match('^v?(%d+)%.(%d+)%.(%d+)%.(%d+)$')
 if not a then return end;return {tonumber(a),tonumber(b),tonumber(c),tonumber(d)}
end
function U.newer(a,b)
 a=U.versionParts(a);b=U.versionParts(b);if not a or not b then return nil end
 for i=1,4 do if a[i]~=b[i]then return a[i]>b[i]end end;return false
end
function U.repository(link)
 if type(link)~='string'then return end
 link=link:match('^%s*(.-)%s*$'):gsub('%.git/?$','')
 local owner,repo=link:match('^https://github%.com/([%w_.%-]+)/([%w_.%-]+)')
 if not owner then owner,repo=link:match('^https://raw%.githubusercontent%.com/([%w_.%-]+)/([%w_.%-]+)/')end
 if not owner or owner=='.'or owner=='..'or repo=='.'or repo=='..'then return end
 return owner..'/'..repo
end
function U.source(fallback)
 local text=love.filesystem.read('client_update_config.json');local cfg
 if text then local ok,d=pcall(require('game.json').decode,text);if ok and type(d)=='table'then cfg=d end end
 if not cfg then local ok,d=pcall(require,'game.client_update_source');if ok then cfg=d end end
 return U.repository(cfg and cfg.repository or fallback)
end
function U.check(fallback)
 U.serial=U.serial+1;local serial=U.serial;U.url=nil;U.latest=nil;U.repo=U.source(fallback)
 if not U.repo then U.state='unconfigured';U.message='Client updates: set a GitHub repository link, then click Check client updates.';return end
 U.state='checking';U.started=love.timer.getTime();U.message='Checking GitHub for client updates...'
 require('game.network').request('https://api.github.com/repos/'..U.repo..'/releases/latest','GET',nil,nil,function(r)
  if serial~=U.serial then return end
  local d=r.data
  if r.status==404 then
   require('game.network').request('https://api.github.com/repos/'..U.repo..'/contents','GET',nil,nil,function(files)
    if serial~=U.serial then return end
    if files.status~=200 or type(files.data)~='table'then U.state='failed';U.message='Client repository unavailable (HTTP '..tostring(files.status)..'). You can sign in or retry.';return end
    local best,version
    for _,file in ipairs(files.data)do
     local v=type(file.name)=='string'and file.name:match('^Stonegrove_(%d+%.%d+%.%d+%.%d+)%.zip$')
     if file.type=='file'and v and (not version or U.newer(v,version))then best=file;version=v end
    end
    if not best then U.state='failed';U.message='No versioned Stonegrove client ZIP found. You can sign in or retry.';return end
    if not U.newer(version,U.version)then U.state='current';U.message='Client '..U.version..' is up to date.';return end
    U.latest=version;U.state='available';U.url='https://github.com/'..U.repo
    local base='https://raw.githubusercontent.com/'..U.repo..'/'
    if type(best.download_url)=='string'and best.download_url:sub(1,#base)==base then U.url=best.download_url end
    U.message='New client '..U.latest..' available. Download and open it before signing in. Your saved characters and login details stay in the LOVE save folder.'
   end)
   return
  end
  if r.status~=200 or type(d)~='table'then U.state='failed';U.message='Client update check unavailable (HTTP '..tostring(r.status)..'). You can sign in or retry.';return end
  local newer=U.newer(d.tag_name,U.version)
  if newer==nil or d.draft or d.prerelease then U.state='failed';U.message='Release must be published with a four-part version tag, e.g. v0.3.63.48. You can sign in or retry.';return end
  if not newer then U.state='current';U.message='Client '..U.version..' is up to date.';return end
  U.latest=d.tag_name;U.state='available';local base='https://github.com/'..U.repo..'/releases/'
  if type(d.html_url)=='string'and d.html_url:sub(1,#base)==base then U.url=d.html_url else U.url=base..'latest'end
  local expected='Stonegrove_'..d.tag_name:gsub('^v','')..'.zip'
  for _,asset in ipairs(type(d.assets)=='table'and d.assets or{})do
   if asset.name==expected and type(asset.browser_download_url)=='string'and asset.browser_download_url:sub(1,#(base..'download/'))==base..'download/'then U.url=asset.browser_download_url;break end
  end
  U.message='New client '..U.latest..' available. Download and open it before signing in. Your saved characters and login details stay in the LOVE save folder.'
 end)
end
function U.update()
 if U.state=='checking'and love.timer.getTime()-U.started>=12 then U.serial=U.serial+1;U.state='failed';U.message='Client update check timed out. You can sign in or retry.'end
end
function U.allowed()return U.state~='checking'and U.state~='available'end
function U.open()
 if U.url and not love.system.openURL(U.url)then U.message='Could not open the browser. Get the latest client from https://github.com/'..U.repo..'/releases/latest'end
end
return U
