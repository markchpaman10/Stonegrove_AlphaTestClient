local N={types={house1='One Story House',house2='Two Story House',modularHouse='Random House',modularHouse1='One Story House',modularHouse2='Two Story House',townCenter='Town Center',storyPOI='Story Point of Interest',skillVendor='Skill Supplies Vendor',bagKeeper='Bag Keeper'}}
function N.catalog(root)
 for _,group in ipairs({{'npc_data.lua','customNPC:'},{'monster_data.lua','custom:'}})do local ok,d=pcall(dofile,root..'/'..group[1]);for _,row in ipairs(ok and d.entries or{})do N.types[group[2]..row.id]=row.name or row.id end end
end
function N.human(id)
 if N.types[id]then return N.types[id]end;local s=tostring(id or'Unknown'):gsub('^customNPC:','NPC '):gsub('^spawn_custom_','Monster '):gsub('[_%-]',' '):gsub('(%l)(%u)','%1 %2')
 return(s:gsub('^%l',string.upper))
end
function N.pair(name,id)return tostring(name and name~=''and name or N.human(id))..'  [ID: '..tostring(id or'?')..']'end
function N.size(z)local area=(z.w or 0)*(z.h or 0);return area<256*256 and'Small'or area<512*512 and'Medium'or'Large'end
function N.ensure(data,map)
 local prefix=tostring(map or'map'):gsub('[^%w%-]','-');local used={};local seen={};for _,group in ipairs({'townZones','objects','spawnZones','levelZones'})do for _,v in ipairs(data[group]or{})do local id=group=='townZones'and v.id or v.placementId;if id then used[id]=true end end end
 for _,group in ipairs({'townZones','objects','spawnZones','levelZones'})do
  for i,v in ipairs(data[group]or{})do
   local key=group=='townZones'and'id'or'placementId';local id=v[key]
   if not id or seen[id]then local n=i;repeat id=prefix..'-'..(group=='townZones'and'town'or'object')..'-'..string.format('%03d',n);n=n+1 until not used[id];v[key]=id end;used[id]=true;seen[id]=true
   if group=='townZones'then v.name=v.name and v.name~=''and v.name or'Town '..i;v.level=math.max(1,math.min(10,math.floor(tonumber(v.level)or 1)));v.size=N.size(v)
   elseif not v.name or v.name==''then v.name=group=='spawnZones'and(N.human(v.enemy)..' Spawn Zone')or N.human(v.id or v.enemy or(group=='levelZones'and'Level Zone'or'Object'))end
  end
 end;return data
end
function N.town(data,x,y)
 for _,z in ipairs(data.townZones or{})do if x>=z.x and x<=z.x+z.w and y>=z.y and y<=z.y+z.h then return z end end
end
function N.map(data,id)local names={};for i,z in ipairs(data.townZones or{})do names[#names+1]=z.name or'Town '..i end;return N.pair(#names>0 and table.concat(names,', ')or'Map',id)end
function N.object(data,o,map)
 local z=N.town(data,o.x or 0,o.y or 0);return(z and(z.name or'Town')..' / 'or'')..N.pair(o.name or N.human(o.id),o.placementId or o.id)..' / Map '..tostring(map or'?')
end
return N
