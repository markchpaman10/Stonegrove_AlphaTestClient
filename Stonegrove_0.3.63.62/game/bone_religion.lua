-- Kill provenance and redemption records are private; ground items carry only their token.
local B={radius=80,requiredGraves=5,lifetime=60,claims={},serial=0,revision=0}
local R=require('game.rune_inventory')
B.parts={Bones={xp=8,x=0},Ribs={xp=16,x=16},['Humanoid Skull']={xp=24,x=32},['Animal Skull']={xp=24,x=48}}
B.piles={['Humanoid Bone Pile']='humanoid',['Animal Bone Pile']='animal',['Cursed Humanoid Bone Pile']='humanoid',['Cursed Animal Bone Pile']='animal'}
function B.base(name)return tostring(name):gsub('^Cursed ','')end
function B.is(name)return B.parts[B.base(name)]~=nil or B.piles[name]~=nil end
function B.cursed(name)return tostring(name):match('^Cursed ')~=nil end
function B.owner(a)return a.campOwner or(a.id and tostring(a.id)..':'..a.slot)or'offline'end
function B.credited(w,p)
 if not p or p.guard or p.kind then return nil end
 for _,a in ipairs(w.onlineActors or{})do if a.player==p or p.onlineOwner==a.id then return tostring(a.id)..':'..a.slot end end
 if SG_SERVER then return nil end
 local profile=require('game.profile').active;return profile and tostring(profile.id)..':'..profile.slot or'offline'
end
function B.hit(w,e,p,damage)
 local owner=B.credited(w,p);if not owner or damage<=0 then return end
 e.boneDamage=e.boneDamage or{};e.boneDamage[owner]=(e.boneDamage[owner]or 0)+damage
 if not e.boneOwner or e.boneDamage[owner]>(e.boneDamage[e.boneOwner]or 0)then e.boneOwner=owner end
end
function B.family(e)
 return(e.humanoid or e.kind=='nagalian'or e.kind=='goblin'or e.kind=='skeleton'or e.kind=='nagaQueen'or e.kind=='ghost')and'humanoid'or'animal'
end
function B.drop(w,e,source,force)
 if e.bonePileDropped then return false end
 -- A guard killing blow suppresses bones, including delayed death sweeps.
 if source and source.guard then e.bonePileDropped=true;return false end
 local physical=({rat=true,wolf=true,boar=true,cow=true,chicken=true,gigaRat=true,caveSnake=true,goblin=true,nagalian=true,skeleton=true,nagaQueen=true})[e.kind]or e.humanoid
 if not physical and not e.cursed and not force then return false end
 e.bonePileDropped=true;local owner=e.boneOwner or B.credited(w,source or w.playerRef);local family=B.family(e);local cursed=e.cursed or e.kind=='nagalian'
 local name=(cursed and'Cursed 'or'')..(family=='humanoid'and'Humanoid'or'Animal')..' Bone Pile'
 B.serial=B.serial+1;local token=tostring(B.serial);local choices={'Bones','Ribs',family=='humanoid'and'Humanoid Skull'or'Animal Skull'};local outputs={}
 for i=1,math.random(1,4)do local part=(cursed and'Cursed 'or'')..choices[math.random(1,3)];outputs[part]=(outputs[part]or 0)+1 end
 B.claims[token]={owner=owner,pile=name,outputs=outputs,phase='pile'};B.revision=B.revision+1
 w:addGroundItem(name,e.x,e.y+12,false,{name=name,qty=1,boneOwner=owner,boneToken=token});return true
end
function B.export()return {claims=R.copy(B.claims),serial=B.serial,revision=B.revision}end
function B.restore(d)B.claims=R.copy(d and d.claims or{});B.serial=d and d.serial or 0;B.revision=d and d.revision or 0 end
function B.checkpoint(inv)
 local out={claims={},serial=B.serial,revision=B.revision};for _,bag in pairs(inv.bagSlots or{})do for _,it in pairs(bag.slots or{})do for token in pairs(require('game.items').boneTokens(it))do out.claims[token]=R.copy(B.claims[token])or false end end end;return out
end
function B.rollback(d)if not d then return end;for token,c in pairs(d.claims)do B.claims[token]=c or nil end;B.serial=d.serial;B.revision=d.revision end
function B.purchase(it)
 local out=R.copy(it);local rolls={};for token,n in pairs(require('game.items').boneTokens(it))do local c=B.claims[token];if c then for i=1,n do rolls[#rolls+1]=R.copy(c.outputs or{})end end end
 if B.piles[it.name]and #rolls>0 then out.boneRolls=rolls;out.boneContents=nil elseif not B.piles[it.name]then out.boneRolls=nil;out.boneContents=nil end;out.boneOwner=nil;out.boneToken=nil;out.boneTokens=nil;out.bonePurchased=true;return out
end
local function key(name,blessed)return name..(blessed and':blessed'or':raw')end
function B.eligible(a,it)
 if not it or it.boneOwner~=B.owner(a)then return false end
 local total=0;for token,n in pairs(require('game.items').boneTokens(it))do local c=B.claims[token];if not c or c.owner~=B.owner(a)then return false end;total=total+n end
 return total==(it.qty or 1),it.boneToken and B.claims[it.boneToken]
end
function B.factor(w,p)
 if not w or not p then return 1 end
 local nearby={};for _,g in ipairs(w.burialGraves or{})do local d=(g.x-p.x)^2+(g.y-p.y)^2;if(g.remaining or 0)>0 and d<=B.radius^2 then nearby[#nearby+1]={grave=g,d=d}end end
 if #nearby<B.requiredGraves then return 1 end;table.sort(nearby,function(a,b)return a.d<b.d end)
 local level=0;for i=1,B.requiredGraves do level=level+math.max(1,nearby[i].grave.ownerLevel or 1)end
 return 1+math.min(1,level/B.requiredGraves/50)
end
function B.command(w,a,cmd)
 local inv=a.inv
 if cmd.op=='boneGraveBless'then
  local found;for _,g in ipairs(w.burialGraves or{})do if g.id==cmd.id then found=g end end
  if not found or found.remaining<=0 then return false,'Burial marker expired'end
  if(found.x-a.player.x)^2+(found.y-a.player.y)^2>55^2 then return false,'Move nearer to the marker'end
  if found.blessed then return false,'This burial marker is already blessed'end
  found.blessed=true;found.blessedBy=a.player.name;found.blessAnimation=.8;B.revision=B.revision+1;a.skills:addXP('Religion',3);return true,'Burial marker blessed'
 end
 local bag=inv:getBag(cmd.bag);local it=bag and bag.slots[cmd.slot]
 if not it or not B.is(it.name)then return false,'Select a bone pile or bone'end
 local Items=require('game.items');local tokens=Items.boneTokens(it)
 local trial=R.clone(inv);local obj=trial:getBag(cmd.bag).slots[cmd.slot];local qty=math.max(1,obj.qty or 1)
 if cmd.op=='boneSeparate'then
  if not B.piles[it.name]then return false,'Select a bone pile'end
  local outputRows={};local total=0
  for token,n in pairs(tokens)do
   local c=B.claims[token];if n~=1 or not c or c.phase~='pile'or c.pile~=it.name or c.owner~=it.boneOwner then return false,'This pile has already been separated'end
   total=total+n;for name,amount in pairs(c.outputs)do outputRows[#outputRows+1]={name=name,qty=amount,boneToken=token,boneOwner=it.boneOwner}end
  end
  if next(tokens)and total~=qty then return false,'Pile quantity does not match its kill records'end
  if not next(tokens)then
   local rolls=it.boneRolls
   if not rolls then rolls={};local choices={'Bones','Ribs',B.piles[it.name]=='humanoid'and'Humanoid Skull'or'Animal Skull'}
    for pile=1,qty do local outputs=it.boneContents and R.copy(it.boneContents)or{};if not it.boneContents then for i=1,math.random(1,4)do local name=(B.cursed(it.name)and'Cursed 'or'')..choices[math.random(1,3)];outputs[name]=(outputs[name]or 0)+1 end end;rolls[pile]=outputs end
    it.boneRolls=R.copy(rolls);it.boneContents=nil
   end
   if #rolls~=qty then return false,'Pile quantity does not match its contents'end
   for _,outputs in ipairs(rolls)do for name,amount in pairs(outputs)do outputRows[#outputRows+1]={name=name,qty=amount}end end
  end
  trial:getBag(cmd.bag).slots[cmd.slot]=nil
  for _,row in ipairs(outputRows)do if not trial:addItemObject(row)then return false,'Make room for the separated bones'end end
  for token in pairs(tokens)do local c=B.claims[token];c.counts={};for name,n in pairs(c.outputs)do c.counts[key(name,false)]=n end;c.phase='parts'end
  inv.bagSlots=trial.bagSlots;B.revision=B.revision+1;return true,'Separated '..qty..' bone piles'
 end
 if not B.eligible(a,it)then return false,'Only bones from your own credited kills can be used for Religion'end
 if not B.parts[B.base(it.name)]then return false,'Separate the pile first'end
 for token,n in pairs(tokens)do local c=B.claims[token];if c.phase~='parts'or n>(c.counts[key(it.name,it.blessed)]or 0)then return false,'These bones are no longer eligible'end end
 if cmd.op=='boneBless'then
  if not B.cursed(it.name)then return false,'Regular bones do not need blessing'end
  if it.blessed then return false,'Already blessed'end
  obj.blessed=true;inv.bagSlots=trial.bagSlots
  for token,n in pairs(tokens)do local c=B.claims[token];c.counts[key(it.name,false)]=c.counts[key(it.name,false)]-n;c.counts[key(it.name,true)]=(c.counts[key(it.name,true)]or 0)+n end
  B.revision=B.revision+1;a.skills:addXP('Religion',qty*2);return true,'Cursed bones blessed'
 elseif cmd.op=='boneBury'then
  if B.cursed(it.name)and not it.blessed then return false,'Bless cursed bones before burying them'end
  local x,y=a.player.x,a.player.y+12
  if not w.map:isLand(x,y)or w:projectileBlocked(x,y)then return false,'Choose open ground for a burial'end
  for _,g in ipairs(w.burialGraves or{})do if(g.x-x)^2+(g.y-y)^2<14^2 then return false,'Leave a little space between graves'end end
  local fuel;for _,n in ipairs({'Pine Logs','Oak Logs','Poplar Logs','Logs'})do if trial:hasItem(n)then fuel=n;break end end
  if not fuel then return false,'Each burial needs 1 log'end
  local consumed=Items.boneTokens(Items.stackPart(obj,1));local token=next(consumed);local c=B.claims[token];local available=c.counts[key(it.name,it.blessed)]
  Items.consumeProvenance(obj,1);obj.qty=qty-1;if obj.qty<=0 then trial:getBag(cmd.bag).slots[cmd.slot]=nil end;assert(trial:removeItems(fuel,1))
  w.burialGraves=w.burialGraves or{};B.serial=B.serial+1
  w.burialGraves[#w.burialGraves+1]={id=B.serial,x=x,y=y,owner=B.owner(a),playerName=a.player.name,ownerLevel=a.skills:get('Religion').level,remaining=B.lifetime,blessed=false,bone=it.name}
  inv.bagSlots=trial.bagSlots;c.counts[key(it.name,it.blessed)]=available-1;local remaining=0;for _,n in pairs(c.counts)do remaining=remaining+n end;if remaining==0 then B.claims[token]=nil end;B.revision=B.revision+1;a.skills:addXP('Religion',B.parts[B.base(it.name)].xp);return true,'Buried '..it.name..' with 1 '..fuel
 end
 return false,'Unknown bone action'
end
function B.update(w,dt)
 for i=#(w.burialGraves or{}),1,-1 do local g=w.burialGraves[i];g.remaining=g.remaining-dt;g.blessAnimation=math.max(0,(g.blessAnimation or 0)-dt);if g.remaining<=0 then table.remove(w.burialGraves,i);B.revision=B.revision+1 end end
end
function B.load(s)
 local images={};for _,cursed in ipairs({false,true})do local file=cursed and'cursed_bones'or'regular_bones';local im=love.graphics.newImage('assets/'..file..'.png');im:setFilter('nearest','nearest');images[cursed and 2 or 1]=im
  local height=im:getHeight()==33 and 17 or 16
  for name,d in pairs(B.parts)do local n=(cursed and'Cursed 'or'')..name;s.itemImages[n]=im;s.itemQuads[n]=love.graphics.newQuad(d.x,16,16,height,im:getDimensions());s.itemInfo[n]={title=n,type='Bone',detail='Own-kill bones only. Bury: 1 log, '..d.xp..' base Religion XP. '..(cursed and'Must be blessed first. 'or'')..'Reserved for future Smithing weapon enhancement.'}end
  for family,x in pairs({Humanoid=32,Animal=48})do local n=(cursed and'Cursed 'or'')..family..' Bone Pile';s.itemImages[n]=im;s.itemQuads[n]=love.graphics.newQuad(x,0,16,16,im:getDimensions());s.itemInfo[n]={title=n,type='Bone Pile',detail='Separate the whole stack to receive 1–4 random bones per pile, including ribs or a '..family:lower()..' skull. Anyone can pick up the pile. Kill ownership is retained; only the credited killer may bless or bury the bones.'}end
 end
end
B.enhancement={enabled=false,station='anvil',skill='Smithing',materials={}}
for n in pairs(B.parts)do B.enhancement.materials[#B.enhancement.materials+1]=n;B.enhancement.materials[#B.enhancement.materials+1]='Cursed '..n end
return B
