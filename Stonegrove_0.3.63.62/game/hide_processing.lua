local H={types={['Soaked Hide']={output='Leather',seconds=10},['Large Soaked Leather']={output='Large Leather',seconds=20},['Extra Large Soaked Hide']={output='Extra Large Leather',seconds=20},['Soaked Cave Snake Hide']={output='Cave Snake Leather',seconds=20}}}
-- One physical rack owns one job. Select the first supported hide in bag order.
function H.use(world,inventory,skills,logger)
 local ok,why=require('game.unlocks').action(skills,'leather');if not ok then return false,why end
 local st=world.hideStretcher
 if st.state=='done' then
  local output=st.output or 'Leather';if not inventory:addItemObject({name=output,qty=1,qualityGrade=st.qualityGrade}) then return false,'bags_full' end
  st.state='empty';st.timer=0;st.duration=nil;st.output=nil;st.input=nil;st.qualityGrade=nil
  if logger then logger:log('LEATHER_COLLECTED_FROM_STRETCHER',{item=output,x=st.x,y=st.y}) end;return true,'collected'
 end
 if st.state~='empty' then return false,'stretcher_busy' end
 local name,def
 for i=1,inventory:bagSlotCount()do local bag=inventory:getBag(i);if bag then for slot=1,bag.size do local obj=bag.slots[slot];if obj and (obj.qty or 1)>0 and H.types[obj.name] then name,def=obj.name,H.types[obj.name];break end end end;if name then break end end
 if not name then return false,'no_soaked_hide' end
 if not inventory:removeItems(name,1) then return false,'remove_failed' end
 st.input=name;st.output=def.output;st.state='stretching';st.timer=def.seconds;st.duration=def.seconds
 if logger then logger:log('HIDE_STRETCHER_LOADED',{seconds=st.timer,item=name,qty=1,x=st.x,y=st.y}) end;return true,'started'
end
function H.update(st,dt,skills,logger)
 if st.state~='stretching' then return end
 st.timer=math.max(0,(st.timer or 0)-dt);if st.timer>0 then return end;st.state='done';st.qualityGrade=require('game.quality').roll(skills:get('Leatherworking').level)
 local old,new,xp=skills:addXP('Leatherworking',10)
 if logger then logger:log('HIDE_STRETCHER_FINISHED',{item=st.output or 'Leather',qty=1,xpGained=10,totalXp=xp,level=new,x=st.x,y=st.y});if new>old then logger:log('SKILL_LEVEL_UP',{skill='Leatherworking',from=old,to=new,totalXp=xp}) end end
end
local function stations(world)
 if world.isCave then world=world.overworld end
 local result,seen={},{}
 local function add(kind,st)if st and not seen[st] and st.x>-90000 then seen[st]=true;result[#result+1]={kind=kind,station=st} end end
 for _,v in ipairs(world.villages or {})do add('hideStretcher',v.hideStretcher);add('tanningVat',v.tanningVat)end
 add('hideStretcher',world.hideStretcher);add('tanningVat',world.tanningVat);return result
end
function H.export(world)
 local out={};for _,row in ipairs(stations(world))do local st=row.station
  out[#out+1]={kind=row.kind,x=st.x,y=st.y,state=st.state,timer=st.timer,duration=st.duration,input=st.input,output=st.output,qualityGrade=st.qualityGrade,jobs=row.kind=='tanningVat' and require('game.items').copy(st.jobs or {}) or nil}
 end;return out
end
function H.restore(world,saved)
 if not saved then return end
 local byKey={};for _,row in ipairs(saved)do byKey[row.kind..':'..row.x..':'..row.y]=row end
 for _,row in ipairs(stations(world))do local st=row.station;local data=byKey[row.kind..':'..st.x..':'..st.y]
  if data then if row.kind=='tanningVat' then st.jobs=require('game.items').copy(data.jobs or {}) else st.state=data.state or 'empty';st.timer=data.timer or 0;st.duration=data.duration;st.input=data.input;st.output=data.output;st.qualityGrade=data.qualityGrade end end
 end
end
return H
