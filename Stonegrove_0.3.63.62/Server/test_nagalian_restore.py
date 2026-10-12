from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r'''
local J=require('game.json');local P=require('game.profile');local R=require('game.regions');local w=SG_SERVER.world
local saved=P.unpack(J.decode(SG_CALL('export','{}')));local room=saved.rooms[R.start]or{};saved.rooms[R.start]=room;room.enemies={}
local wild=w.makeExpansionEnemy('nagaQueen',500,500,1);wild.netId=990001;local editor=w.makeExpansionEnemy('nagaQueen',600,500,1);editor.editorSpawnZone=1;editor.netId=990002
room.enemies[#room.enemies+1]=wild;room.enemies[#room.enemies+1]=editor;SG_CALL('restore',J.encode(P.pack(saved)))
local player=require('game.player').new();local skills=require('game.skills').new();local inv=require('game.inventory').new();inv:add('Copper Knife',1)
local request={id=990,owner=990,slot=1,seq=1,name='QA',race='Human',worldId=R.doc.worldId,worldFingerprint=R.networkFingerprint,regionId=R.start,area='overworld',initial=true,personal=P.pack({player=player,skills=skills.data,bags=inv.bagSlots,equipment={}})}
local reply=J.decode(SG_CALL('exchange',J.encode(request)));local snapshot=P.unpack(reply.snapshot);local found=false
for _,e in ipairs(snapshot.enemies)do assert(e.netId~=990001,'Procedural Queen removed on restore');assert(e.netId~=990002,'Old editor enemy instance must not persist');if e.kind=='nagalian'then assert(e.headVariant and e.bodyVariant and e.weapon,'Appearance/weapon replicated')end end
local data=require('game.items').copy(w.map.authored);local N=require('game.naga_queen');local x,y;for yy=160,w.map.height-160,160 do for xx=160,w.map.width-160,160 do if not x and N.allowed(w,xx,yy)and not w:enemyBlocked(xx,yy)then x,y=xx,yy end end end;assert(x);data.spawnZones={{enemy='nagaQueen',x=x-32,y=y-32,w=64,h=64,count=1,level=12}};local authored=require('game.world').new(SG_SERVER.sprites,data);for _,e in ipairs(authored.enemies)do if e.kind=='nagaQueen'and e.editorSpawnZone then found=true end end;assert(found,'Editor Queen generated from authored spawn definition')
local corpse;for _,e in ipairs(w.enemies)do if e.kind=='nagalian'and not e.campId then corpse=e;break end end;assert(corpse);corpse.dead=true;corpse.skinned=false
request.seq=2;request.personal=P.pack({player=player,skills=skills.data,bags=inv.bagSlots,equipment={}});player.x,player.y=corpse.x,corpse.y;request.personal=P.pack({player=player,skills=skills.data,bags=inv.bagSlots,equipment={}});request.action={kind='skin',id=corpse.netId};request.action.target=corpse.netId
local response=J.decode(SG_CALL('exchange',J.encode(request)));assert(response.result and response.result.ok,'Server skin action accepted')
return 'PASS runtime snapshot removal/authored spawn regeneration and replicated Nagalian appearance/weapon/server skin action'
'''))
finally:s.close()
