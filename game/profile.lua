local P={pending=nil,busy=false,revision=0}
local J=require('game.json')
function P.pack(v,seen)
 if type(v)~='table'then if type(v)=='string'or type(v)=='number'or type(v)=='boolean'then return v end;return nil end
 seen=seen or{};if seen[v]then return nil end;seen[v]=true;local count=0;local array=true;for k in pairs(v)do count=count+1;if type(k)~='number'or k<1 or k%1~=0 then array=false end end
 for i=1,count do if v[i]==nil then array=false;break end end
 if array and count>0 and #v==count then local out={array={}};for i=1,count do local value=P.pack(v[i],seen);out.array[i]=value==nil and {nilValue=true}or value end;seen[v]=nil;return out end
 local out={entries={}};for k,x in pairs(v)do if type(k)=='string'or type(k)=='number'then local value=P.pack(x,seen);if value~=nil then out.entries[#out.entries+1]={key=k,value=value}end end end;seen[v]=nil;return out
end
function P.unpack(v,depth)
 if type(v)~='table'then return v end;if v.nilValue==true then return nil end;depth=(depth or 0)+1;assert(depth<100,'Invalid character nesting');local out={};if v.array then assert(type(v.array)=='table','Invalid array');for i,x in ipairs(v.array)do out[i]=P.unpack(x,depth)end;return out end;assert(type(v.entries)=='table','Invalid character table');for _,e in ipairs(v.entries)do assert(type(e)=='table'and(type(e.key)=='string'or type(e.key)=='number'),'Invalid character key');assert(out[e.key]==nil,'Duplicate character key');out[e.key]=P.unpack(e.value,depth)end;return out
end
function P.path(file)return P.active and('profiles/'..P.active.id..'/'..P.active.slot..'/'..file)or file end
function P.install()
 if P.installed then return end;P.installed=true
 for _,name in ipairs({'load','getInfo','write','read'})do local old=love.filesystem[name];love.filesystem[name]=function(path,...)if path=='character_save.lua'or path=='race_preference.lua'then path=P.path(path)end;return old(path,...)end end
end
function P.activate(session,slot,record)
 assert(type(session.id)=='number'and session.id>0 and session.id%1==0 and type(slot)=='number'and slot>=1 and slot<=3 and slot%1==0,'Invalid account or character slot')
 assert(not P.busy and not P.pending,'Save must finish before switching characters');P.active={id=session.id,slot=slot};P.session=session;P.revision=record.revision or 0;local dir='profiles/'..session.id..'/'..slot;love.filesystem.createDirectory(dir)
 if record.character then local d=P.unpack(J.decode(record.character.save));assert(type(d.player)=='table'and ({Human=true,Elf=true,Dwarf=true})[d.player.race],'Invalid character save');assert(love.filesystem.write('character_save.lua','return '..require('EditorShared.model').serialize(d)))else love.filesystem.remove(dir..'/character_save.lua')end
end
function P.queue(data)
 if not P.active then return end
 P.pending={name=data.player.name or'Adventurer',race=data.player.race or'Human',save=J.encode(P.pack(data))};love.filesystem.write(P.path('pending.json'),J.encode({revision=P.revision,character=P.pending}));P.error=nil
end
function P.acceptAuthoritative(revision)
 if type(revision)~='number'or revision<=P.revision then return false end
 P.revision=revision;P.pending=nil;P.error=nil;love.filesystem.remove(P.path('pending.json'));return true
end
function P.update()
 if not P.pending or P.busy or P.error then return end;P.busy=true;local sent=P.pending;local sentRevision=P.revision;P.pending=nil
 require('game.network').request(P.session.server..'/v1/characters/'..P.active.slot,'PUT',{revision=P.revision,character=sent},P.session.token,function(r)
  P.busy=false;if P.revision>sentRevision then if P.pending then love.filesystem.write(P.path('pending.json'),J.encode({revision=P.revision,character=P.pending}))else love.filesystem.remove(P.path('pending.json'))end;return end;if r.status==200 then P.revision=r.data.revision;if P.pending then love.filesystem.write(P.path('pending.json'),J.encode({revision=P.revision,character=P.pending}))else love.filesystem.remove(P.path('pending.json'))end else P.pending=P.pending or sent;P.error=(r.data and r.data.error)or'Cannot sync character; local backup kept';love.filesystem.write(P.path('pending.json'),J.encode({revision=P.revision,character=P.pending}))end
 end)
end
return P
