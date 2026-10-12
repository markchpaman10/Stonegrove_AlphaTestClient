local N={jobs={},serial=0}
function N.request(url,method,data,token,callback,raw)
 N.serial=N.serial+1;local name='stonegrove_net_'..N.serial;local root=love.filesystem.getSource():gsub('\\','/');local code=string.format([[package.path=%q..'/?.lua;'..package.path;local channel,url,method,body,token=...;local ok,result=pcall(require('game.http').request,url,method,body,token);love.thread.getChannel(channel):push(ok and result or {status=0,body=tostring(result)})]],root)
 local thread=love.thread.newThread(code..string.char(10));N.jobs[#N.jobs+1]={thread=thread,channel=love.thread.getChannel(name),callback=callback,raw=raw};thread:start(name,url,method or'GET',data and require('game.json').encode(data)or'',token)
end
function N.update()
 for i=#N.jobs,1,-1 do local job=N.jobs[i];local r=job.channel:pop();local err=job.thread:getError();if r or err then table.remove(N.jobs,i);r=r or{status=0,body=err};if not job.raw and r.status>0 then local ok,value=pcall(require('game.json').decode,r.body);if ok then r.data=value else r.status=0;r.body='Invalid server response'end end;job.callback(r)end end
end
return N
