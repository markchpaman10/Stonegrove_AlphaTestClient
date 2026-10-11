local M={}
function M.read(path)
 local f,e=io.open(path,'rb');if not f then return nil,e end;local text=f:read('*a');f:close();local chunk,err=loadstring(text,'@'..path);if not chunk then return nil,err end;local ok,d=pcall(chunk);if not ok or type(d)~='table' then return nil,'Invalid data: '..tostring(d)end;return d,text
end
function M.copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=M.copy(x)end;return out end
function M.serialize(v)
 local kind=type(v);if kind=='string'then return string.format('%q',v)elseif kind=='number'or kind=='boolean'then return tostring(v)elseif kind~='table'then return 'nil'end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)if type(a)==type(b)then return a<b end;return type(a)<type(b)end)
 local rows={'{'};for _,k in ipairs(keys)do rows[#rows+1]='['..M.serialize(k)..']='..M.serialize(v[k])..',\n'end;rows[#rows+1]='}';return table.concat(rows)
end
function M.write(path,data,expected)
 local _,current=M.read(path);if expected and current~=expected then return false,'Changed in another editor. Reload with F5 before saving.'end
 local text='return '..M.serialize(data)..'\n';local chunk,err=loadstring(text);if not chunk then return false,err end
 local f,e=io.open(path..'.tmp','wb');if not f then return false,e end;local ok,msg=f:write(text);f:close();if not ok then return false,msg end
 local existing=io.open(path,'rb');if existing then existing:close();os.remove(path..'.bak');local moved,why=os.rename(path,path..'.bak');if not moved then os.remove(path..'.tmp');return false,why end end
 local moved,why=os.rename(path..'.tmp',path);if not moved then if existing then os.rename(path..'.bak',path)end;return false,why end;return true,text
end
function M.world(root)
 local d,text=M.read(root..'/current.lua');if not d then return nil,'Cannot load the game current.lua: '..tostring(text)end
 local maps=d.maps or {{id='root',data=d}};local index=1;for i,map in ipairs(maps)do if map.id==d.startMap then index=i end end;return {doc=d,maps=maps,index=index,text=text,root=root}
end
function M.spawnWarning(data,x,y)
 for _,z in ipairs(data.townZones or{})do if x>=z.x-48 and x<=z.x+z.w+48 and y>=z.y-48 and y<=z.y+z.h+48 then return 'Town protection may prevent spawning here.'end end
 for _,o in ipairs(data.objects or{})do local dx,dy=math.abs(x-o.x),math.abs(y-o.y);if dx<=72 and dy<=72 or(o.id=='house1'or o.id=='house2')and dx<=130 and dy<=126 then return 'Object/NPC protection may prevent spawning here.'end end
 for _,p in ipairs(data.paths or{})do if x>=p.x-64 and x<=p.x+80 and y>=p.y-64 and y<=p.y+80 then return 'Path protection may prevent spawning here.'end end
end
function M.place(w,kind,id,x,y,definition,count)
 local data=w.maps[w.index].data or w.maps[w.index];local width,height=(data.cols or 640)*16,(data.rows or 480)*16
 x=math.max(8,math.min(width-8,math.floor(x/16)*16+8));y=math.max(8,math.min(height-8,math.floor(y/16)*16+8))
 if not w.landMask or w.landMap~=data then w.landMask={};w.landMap=data;for _,key in ipairs(data.landCells or{})do w.landMask[key]=true end end
 local tile=math.floor(y/16)*(data.cols or 640)+math.floor(x/16);if not w.landMask[tile]then return nil,'Choose land for this placement.'end
 if kind=='monster'then data.spawnZones=data.spawnZones or {};data.spawnZones[#data.spawnZones+1]={enemy='custom:'..id,x=x-32,y=y-32,w=64,h=64,level=tonumber(definition.level)or 1,count=count or 1}
 else data.objects=data.objects or {};data.objects[#data.objects+1]={id=(kind=='npc'and 'customNPC:'or 'customItem:')..id,x=x,y=y,qty=1}end
 w.dirty=true;return x,y
end
function M.validate(rows,kind,items)
 local ids={};for i,row in ipairs(rows)do local id=row.id;if type(id)~='string'or id==''or id:find('[\r\n:]')then return false,'Definition '..i..' needs an ID without colon/newline.'end;if ids[id]then return false,'Duplicate ID: '..id end;ids[id]=true
  if kind=='monster'then
   if not ({rat=true,wolf=true,boar=true,slime=true,goblin=true,humanoid=true,nagalian=true,nagaQueen=true})[row.baseSprite]then return false,'Choose an animal, goblin, humanoid, Nagalian or Naga Queen appearance.'end
   for _,k in ipairs({'level','melee','ranged','strength','agility','health','aggro','speed','drop1Qty','drop2Qty'})do local v=tonumber(row[k]);if not v or v~=v or v<0 or v>10000 then return false,'Invalid monster number: '..k end;if k=='level'and(v<1 or v>100)then return false,'Monster level must be 1-100.'end end
   for _,k in ipairs({'drop1','drop2'})do if row[k]~=''and items and not items[row[k]]then return false,'Unknown drop item: '..row[k]end end
  elseif kind=='item'then for _,k in ipairs({'stackMax','value'})do local v=tonumber(row[k]);if not v or v~=v or v<1 or v>1000000 or v~=math.floor(v)then return false,k..' must be a positive whole number.'end end;if items and not items[row.iconBase]then return false,'Choose an existing Icon Base item.'end
  elseif row.race~='Human'and row.race~='Elf'and row.race~='Dwarf'then return false,'Race must be Human, Elf or Dwarf.'elseif row.gender~='male'and row.gender~='female'then return false,'Gender must be male or female.'end
  if kind=='monster'and row.baseSprite=='humanoid'and not({Human=true,Elf=true,Dwarf=true})[row.race]then return false,'Choose a humanoid race.'end
  if kind=='item' then
   if row.equipSlot and row.equipSlot~='' and not ({head=true,body=true,legs=true,cape=true,weapon=true,offhand=true})[row.equipSlot]then return false,'Choose a valid equipment slot.'end
   if row.spritePath and row.spritePath~=''then if not row.spritePath:match('^assets/imported/[%w_%-]+%.png$')then return false,'Import a paper-doll PNG using drag and drop.'end;for _,k in ipairs({'frameWidth','frameHeight'})do local n=tonumber(row[k]);if not n or n<1 or n~=math.floor(n)then return false,'Invalid frame size: '..k end end end
   for _,k in ipairs({'damage','defence','accuracy','requiredLevel','anchorX','anchorY','attackSpeed'})do if row[k] and row[k]~=''then local n=tonumber(row[k]);if not n or n~=n or n<0 or n==math.huge or(k=='attackSpeed'and n<=0)then return false,'Invalid item number: '..k end end end
   if row.requiredLevel and row.requiredLevel~=''then local level=tonumber(row.requiredLevel);if level<1 or level>99 or level%1~=0 then return false,'Required level must be an integer from 1 to 99.'end end
  elseif kind=='npc'or(kind=='monster'and row.baseSprite=='humanoid')then
   local types={head='Head Armor',body='Body Armor',legs='Foot Armor',cape='Cape',weapon='Weapon',offhand='Offhand'}
   for slot,typ in pairs(types)do local id=row['equip_'..slot];if id and id~=''then local d=items and items[id];if not d or not(d.slot==slot or d.type==typ or(slot=='weapon'and d.type=='Tool'))then return false,'Invalid '..slot..' equipment: '..id end end end
  end
 end;return true
end
return M
