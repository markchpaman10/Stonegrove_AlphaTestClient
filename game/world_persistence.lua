-- Durable recovery state only. Generated scenery and live actor graphs never persist.
local W={version=2,lists={'groundItems','gravestones','burialGraves','campfires','pendingRuneDrops'}}
local function copy(v)return require('game.items').copy(v)end
local function scalar(v)local out={};for k,x in pairs(v)do if type(x)=='string'or type(x)=='boolean'or(type(x)=='number'and x==x and math.abs(x)<math.huge)then out[k]=x end end;out.netId=nil;return out end
function W.capture(w)
 require('game.ground_lifetime').update(w)
 local d={graveSerial=w.graveSerial or 0,graveRevision=w.graveRevision or 0}
 for _,name in ipairs(W.lists)do d[name]={};for _,v in ipairs(w[name]or{})do
  if name~='campfires'or not(v.permanent or v.fieldcraftCamp or v.goblinCamp or v.campIndex)then
   local row=scalar(v);for _,key in ipairs({'object','contents','queuedLogs','source'})do if v[key]then row[key]=copy(v[key])end end;d[name][#d[name]+1]=row
  end
 end end
 local entry=w.recoveryPoint or w.entry;if entry then d.recoveryPoint={x=entry.x,y=entry.y}end
 return d
end
function W.has(d)for _,name in ipairs(W.lists)do if next(d[name]or{})then return true end end;return false end
function W.normalize(rooms)
 local out={}
 local keys={};for key in pairs(rooms or{})do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys)do local data=W.capture(rooms[key]);local region=key:match('^(.-)/cave/%d+$')or key
  if W.has(data)then local dest=out[region]or{graveSerial=0,graveRevision=0};out[region]=dest;dest.graveSerial=math.max(dest.graveSerial,data.graveSerial);dest.graveRevision=math.max(dest.graveRevision,data.graveRevision)
   for _,name in ipairs(W.lists)do dest[name]=dest[name]or{};for i,v in ipairs(data[name])do
    if region~=key then local p=data.recoveryPoint or{x=200,y=200};v.x,v.y=p.x+20+(i%4)*3,p.y+36;v.relocatedFromCave=true;if v.source then v.source={x=v.x,y=v.y}end end
    dest[name][#dest[name]+1]=v
   end end
  end
 end;return out
end
function W.camps(w)
 local out={};for _,camp in ipairs(w.goblinCamps or{})do local c=scalar(camp);c.tents={};c.decor={};for _,t in ipairs(camp.tents or{})do c.tents[#c.tents+1]=scalar(t)end;for _,d in ipairs(camp.decor or{})do c.decor[#c.decor+1]=scalar(d)end
  if camp.cage then c.cage=scalar(camp.cage)end;out[#out+1]=c
 end;return out
end
return W
