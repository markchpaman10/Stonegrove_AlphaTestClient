local L={screen='login',fields={'','','',''},focus=1,status='Paste the account server URL supplied by the developer, then sign in or create an account.',buttons={},offline=false}
local Updates=require('game.client_updates');local Input=require('game.launcher_input');local N=require('game.network');local J=require('game.json');local P=require('game.profile');local W=require('game.world_package')
local function fail(r)return r.data and r.data.error or(r.status==0 and 'Connection failed. Check the account server address.'or'HTTP '..r.status)end
local function config(authenticated)
 if authenticated then L.passwordCipher=require('game.login_memory').protect(L.fields[3]);L.savedServer=L.fields[1];L.savedUser=L.fields[2]end
 local cipher=L.savedServer==L.fields[1]and L.savedUser==L.fields[2]and L.passwordCipher or nil
 love.filesystem.write('launcher_config.json',J.encode({server=L.fields[1],github=L.fields[4],username=L.fields[2],passwordCipher=cipher,credentialServer=cipher and L.fields[1]or nil}))
end
local function request(path,method,data,cb)N.request(L.session.server..path,method,data,L.session.token,cb)end
function L.slots()
 L.screen='slots';L.wait=true;L.deleteSlot=nil;L.status='Loading characters…';request('/v1/characters','GET',nil,function(r)L.wait=false;if r.status==200 then L.characters=r.data.slots;L.status='Choose one of your three characters.'else L.status=fail(r)end end)
end

function L.askDelete(slot)
 if L.wait or P.busy or P.pending then return end
 local row=L.characters and L.characters[slot];if not row or row.name==''then return end
 L.deleteSlot=slot;L.deleteRow={name=row.name,revision=row.revision};L.screen='delete';L.status='Deleting removes this character, its inventory, progress and camp. This cannot be undone.'
end
function L.cancelDelete()
 if L.wait then return end;L.deleteSlot=nil;L.deleteRow=nil;L.screen='slots';L.status='Deletion cancelled.'
end
function L.deleteCharacter()
 if L.wait or not L.deleteSlot or not L.deleteRow or P.busy or P.pending then return end
 local slot=L.deleteSlot;local row=L.deleteRow;local dir='profiles/'..L.session.id..'/'..slot..'/'
 local files={'pending.json','character_save.lua','race_preference.lua'}
 for _,name in ipairs(files)do local bytes=love.filesystem.read(dir..name);if bytes then local ok=love.filesystem.write(dir..name..'.deleted-'..row.revision..'.backup',bytes);if not ok then L.status='Could not preserve the local backup. Character was not deleted.';return end end end
 L.wait=true;L.status='Deleting '..row.name..'...'
 request('/v1/characters/'..slot,'DELETE',{revision=row.revision,name=row.name},function(r)
  L.wait=false;if r.status~=200 then L.status=fail(r);return end
  for _,name in ipairs(files)do love.filesystem.remove(dir..name)end
  if P.active and P.active.id==L.session.id and P.active.slot==slot then P.active=nil;P.revision=r.data.revision;P.error=nil end
  L.recoverSlot=nil;L.deleteRow=nil;L.slots()
 end)
end

function L.authenticate(register)
 if not Updates.allowed()then L.status=Updates.message;return end
 L.offline=false
 if L.wait then return end;L.wait=true;config();L.status='Connecting…';N.request(L.fields[1]:gsub('/+$','')..(register and'/v1/register'or'/v1/login'),'POST',{name=L.fields[2],password=L.fields[3]},nil,function(r)L.wait=false;if r.status~=200 then L.status=fail(r);return end;config(true);L.fields[3]='';L.session=r.data;L.session.server=L.fields[1]:gsub('/+$','');love.filesystem.write('launcher_session.json',J.encode(L.session));L.slots()end)
end
function L.play(slot)
 if L.wait then return end;L.wait=true;request('/v1/characters/'..slot,'GET',nil,function(r)L.wait=false;if r.status~=200 then L.status=fail(r);return end
  local pendingPath='profiles/'..L.session.id..'/'..slot..'/pending.json';if love.filesystem.getInfo(pendingPath)then L.status='An unsynced backup exists for this slot. Use Recover backup before playing.';L.recoverSlot=slot;return end
  local ok,err=pcall(P.activate,L.session,slot,r.data);if not ok then L.status=tostring(err);return end;L.screen='loading';L.status='Loading character and world maps…';L.pendingCharacter=r.data;L.confirmed=r.data.character~=nil;love.keyboard.setTextInput(not r.data.character)
 end)
end
function L.recover()
 if not L.recoverSlot then return end;local slot=L.recoverSlot;local path='profiles/'..L.session.id..'/'..slot..'/pending.json';local ok,backup=pcall(J.decode,love.filesystem.read(path));if not ok then L.status='Backup is invalid; it has been preserved.';return end
 request('/v1/characters/'..slot,'PUT',backup,function(r)if r.status==200 then love.filesystem.remove(path);L.recoverSlot=nil;L.slots()else L.status=fail(r)..' Backup: '..love.filesystem.getSaveDirectory()..'/'..path end end)
end
function L.importLegacy()
 local slot;for i,row in ipairs(L.characters or{})do if row.name=='' then slot=i;break end end;if not slot then L.status='All three slots are occupied.';return end
 local chunk=love.filesystem.load('character_save.lua');if not chunk then L.status='No legacy character found on this computer.';return end;local ok,d=pcall(chunk);if not ok or type(d)~='table'or type(d.player)~='table'then L.status='Legacy character could not be read.';return end
 request('/v1/characters/'..slot,'PUT',{revision=L.characters[slot].revision or 0,character={name=d.player.name or'Adventurer',race=d.player.race or'Human',save=J.encode(P.pack(d))}},function(r)if r.status==200 then L.slots()else L.status=fail(r)end end)
end
function L.useServerCopy()
 if not L.recoverSlot then return end;local slot=L.recoverSlot;local path='profiles/'..L.session.id..'/'..slot..'/pending.json';local bytes=love.filesystem.read(path);if bytes then local ok=love.filesystem.write(path..'.conflict-'..os.time()..'.json',bytes);if not ok then L.status='Could not preserve local backup.';return end;love.filesystem.remove(path)end;L.recoverSlot=nil;L.play(slot)
end
function L.returnSlots()
 if L.screen~='game'or L.leaving then return end;if player and inventory and skills and ui and L.confirmed then require('game.save').write(player,inventory,skills,ui,logger)end;L.leaving=true;L.status='Saving character…'
end
function L.install()
 L.game={};for _,name in ipairs({'load','update','draw','mousepressed','mousereleased','mousemoved','wheelmoved','keypressed','keyreleased','textinput','filedropped','quit','resize','enterSelectedCharacter'})do L.game[name]=love[name]end
 love.load=function()P.install();local cfg=love.filesystem.read('launcher_config.json');if cfg then local ok,d=pcall(J.decode,cfg);if ok then L.fields[1]=d.server or L.fields[1];L.fields[4]=d.github or'';L.fields[2]=d.username or'';if d.credentialServer==L.fields[1]then L.fields[3]=require('game.login_memory').unprotect(d.passwordCipher)or'';L.passwordCipher=d.passwordCipher;L.savedServer=L.fields[1];L.savedUser=L.fields[2]end end end;local ok,err=W.restore();if not ok then L.status='Previous world could not load: '..tostring(err)end;love.keyboard.setTextInput(true);Updates.check(L.fields[4])end
 love.update=function(dt)N.update();Updates.update();P.update();if L.screen=='loading'and L.pendingCharacter then L.pendingCharacter=nil;local ok,err=pcall(function()L.game.load();require('game.regions').preload(sprites,function(id,i,n)L.status='Loading map '..i..' / '..n..' ('..id..')';love.graphics.clear(.055,.07,.06);love.graphics.setColor(1,1,1);love.graphics.printf(L.status,40,love.graphics.getHeight()/2,love.graphics.getWidth()-80,'center');love.graphics.present();love.event.pump()end);L.game.enterSelectedCharacter();L.screen='game'end);if not ok then L.screen='slots';L.status='Loading failed: '..tostring(err)end end;if L.screen=='game'and not L.leaving then if L.game.update then L.game.update(dt)end end;if L.leaving and not P.busy and not P.pending then L.leaving=false;if logger then logger:close('characters');logger=nil end;P.active=nil;L.confirmed=false;L.slots();love.keyboard.setTextInput(true)end;if L.quitting and not P.busy and not P.pending then L.readyQuit=true;love.event.quit()end end
 love.draw=function()if L.screen=='game'then L.game.draw();if L.offline then local g=love.graphics;g.setColor(.03,.04,.03,.88);g.rectangle('fill',12,12,210,26,4);g.setColor(1,.82,.45);g.print('OFFLINE DEVELOPMENT',20,18);g.setColor(1,1,1)end;if P.error or L.leaving then love.graphics.setColor(0,0,0,.9);love.graphics.rectangle('fill',0,0,love.graphics.getWidth(),42);love.graphics.setColor(1,.8,.4);love.graphics.print(P.error or L.status,12,12)end;return end
  local g=love.graphics;g.push();g.scale(g.getWidth()/1100,g.getHeight()/700);g.clear(.055,.07,.06);g.setColor(1,.87,.55);g.print('STONEGROVE — Account Launcher',40,24);L.buttons={};local function button(text,x,y,w,fn)g.setColor(.2,.26,.2);g.rectangle('fill',x,y,w,38,4);g.setColor(1,1,1);g.printf(text,x,y+11,w,'center');L.buttons[#L.buttons+1]={x=x,y=y,w=w,h=38,fn=fn}end
  if L.screen=='loading'then g.setColor(1,1,1);g.printf('Loading character and all world maps…',40,320,1020,'center')
  elseif L.screen=='delete'then g.setColor(1,.75,.65);g.printf('Delete '..(L.deleteRow and L.deleteRow.name or'character')..'?',40,110,900,'left');g.setColor(1,1,1);g.printf('Permanently remove character slot '..tostring(L.deleteSlot)..'? Your other characters and account stay.',40,160,900,'left');button('Cancel',40,235,180,L.cancelDelete);button('DELETE CHARACTER',240,235,260,L.deleteCharacter)
  elseif L.screen=='login'then for i,label in ipairs({'Account server URL','Account name','Password','GitHub repository / world download link'})do local y=65+(i-1)*76;g.setColor(.8,.85,.8);g.print(label,40,y);g.setColor(i==L.focus and .22 or .13,.19,.15);g.rectangle('fill',40,y+24,760,34);g.setColor(1,1,1);Input.draw(L,i,48,y+32,744)end;button('Sign in ONLINE',40,382,180,function()L.authenticate(false)end);button('Create account',240,382,180,function()L.authenticate(true)end);g.setColor(.65,.72,.65);g.print('Client 0.3.63.48',720,393)
  else g.setColor(1,1,1);g.print(L.session.name..'  ('..L.session.role..')',40,64);for i=1,3 do local row=L.characters and L.characters[i];button(row and row.name~=''and(row.name..' · '..row.race)or('Create character '..i),40,100+(i-1)*60,540,function()L.play(i)end);if row and row.name~=''then button('Delete',600,100+(i-1)*60,140,function()L.askDelete(i)end)end end;button('Log out',40,300,160,function()request('/v1/logout','POST',{},function()end);love.filesystem.remove('launcher_session.json');L.session=nil;L.screen='login';L.status='Signed out.'end);button('Recover backup',220,300,180,L.recover);button('Import old character',420,300,180,L.importLegacy);if L.recoverSlot then button('Use server copy',620,300,180,L.useServerCopy)else button('Refresh characters',620,300,180,L.slots)end

  end
  if L.screen=='login'then g.setColor(.85,.88,.8);g.printf(Updates.message,40,444,1020,'left');button(Updates.state=='available'and 'Download latest client'or 'Check client updates',40,514,290,function()if Updates.state=='available'then Updates.open()elseif Updates.state~='checking'then Updates.check(L.fields[4])end end)end
  button('Update world from GitHub',40,572,290,L.download);g.setColor(.8,.86,.8);g.printf(L.status,40,624,1020,'left');g.print('Drop a .sgworld file here to import it.  Ctrl+L returns from the game.',40,674);g.pop()
 end
 love.mousepressed=function(x,y,b,...)if L.screen=='game'then if L.game.mousepressed then L.game.mousepressed(x,y,b,...)end;return end;if L.wait then return end;x=x*1100/love.graphics.getWidth();y=y*700/love.graphics.getHeight();if b==1 then if L.screen=='login'then for i=1,4 do local top=89+(i-1)*76;if x>=40 and x<=800 and y>=top and y<=top+34 then Input.click(L,i,x-48)end end end;for _,btn in ipairs(L.buttons)do if x>=btn.x and x<=btn.x+btn.w and y>=btn.y and y<=btn.y+btn.h then btn.fn();break end end end end
 love.textinput=function(text)if L.screen=='game'then if L.game.textinput then L.game.textinput(text)end elseif L.screen=='login'then Input.insert(L,text)end end
 love.keypressed=function(key,...)if L.screen=='game'then if key=='r'and love.keyboard.isDown('lctrl','rctrl')then P.error=nil;return end;if key=='q'and love.keyboard.isDown('lctrl','rctrl')and love.keyboard.isDown('lshift','rshift')then if L.confirmed then L.game.quit()end;L.readyQuit=true;love.event.quit();return end;if key=='l'and love.keyboard.isDown('lctrl','rctrl')then if L.offline then if L.game.quit then L.game.quit()end;L.offline=false;L.screen='login';L.status='Returned from offline development.';love.keyboard.setTextInput(true)else L.returnSlots()end;return end;if L.game.keypressed then L.game.keypressed(key,...)end else if L.screen=='delete'and key=='escape'then L.cancelDelete();return end;if L.wait then return end;if L.screen=='login'and Input.key(L,key)then return end;if key=='tab'then L.focus=L.focus%4+1 elseif key=='backspace'then local s=L.fields[L.focus];L.fields[L.focus]=s:sub(1,(require('utf8').offset(s,-1)or 1)-1)elseif key=='return'and L.screen=='login'then L.authenticate(false)end end end
 for _,event in ipairs({'mousereleased','mousemoved','wheelmoved','keyreleased','resize'})do love[event]=function(...)if L.screen=='game'and L.game[event]then return L.game[event](...)end end end
 love.filedropped=function(file)if L.screen=='game'then L.status='Return to the launcher before importing a world.';return end;file:open('r');local bytes=file:read();file:close();local ok,err=pcall(W.activate,bytes);L.status=ok and'World imported. Character saves were kept.'or tostring(err)end
 love.quit=function()if L.readyQuit then return false end;if L.screen=='game'and L.offline then if L.game.quit then L.game.quit()end;return false end;if L.screen=='game'and L.confirmed then if not L.quitting then L.game.quit();L.quitting=true end;if P.busy or P.pending then if P.error then L.status=P.error;L.quitting=false end;return true end end;return false end
end
function L.download()
 config();L.status='Checking GitHub…';W.github(L.fields[4],function(url,err)if not url then L.status=err;return end;N.request(url,'GET',nil,nil,function(r)if r.status~=200 then L.status='World download failed (HTTP '..r.status..')';return end;local ok,e=pcall(W.activate,r.body);L.status=ok and'World updated. Choose a character to play.'or tostring(e)end,true)end)
end
return L
