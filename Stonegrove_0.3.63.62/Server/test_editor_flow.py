"""NPC interaction precedence, appearance links and cave lifecycle; isolated simulation."""
from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent)
try:
 print(s.eval(r"""
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local w=SG_SERVER.world;local C=require('game.caves');C.ensure(w)
check(#w.caveEntrances==3,'Three random caves initially')
local first=w.caveEntrances[1];local room=C.generate(w,first);w.caveInstances[first.id]=room
for _,e in ipairs(room.enemies)do check(e.level>=first.levelMin and e.level<=first.levelMax,'All cave enemies and bosses match encounter band')end;check(not C.cleared(room),'Living cave remains open');for _,e in ipairs(room.enemies)do e.dead=true;e.hp=0 end
check(C.cleared(room)and first.closing,'Dead cave closes');check(C.remove(w,first.id),'Remove cleared random cave');check(not C.remove(w,first.id),'Idempotent removal');C.replenish(w);check(#w.caveEntrances==3,'Replenishes maximum');for _,e in ipairs(w.caveEntrances)do check(e.id~=first.id,'No stale cave ID reuse')end
local recovered={nodes={},map=w.map};C.restore(recovered,{{id=44,x=1000,y=1000,closing=true},{id=45,x=1000,y=1200,authored=true,closing=true}});check(#recovered.caveEntrances==1 and recovered.caveEntrances[1].id==45,'Offline restore retires cleared caves but preserves authored');check(recovered._nextCaveId==46,'Restore preserves next stable cave ID')
local authored={id=100,x=1000,y=1000,seed=1,authored=true};local fake={isCave=true,entry=authored,enemies={{dead=true,hp=0}}};check(not C.cleared(fake),'Authored cave retained');fake.entry={questSpawnKey='qa'};check(not C.cleared(fake),'Quest cave retained')
local L=require('game.level_zones');local map={authored={mapInfo={levelMin=1,levelMax=20},levelZones={}}};local localZone={x=0,y=0,w=100,h=100,level=18,levelMode='local'};local sum=0;for i=1,100 do local lv=L.spawnLevel(map,localZone,50,50);check(lv>=1 and lv<=20,'Spawn-local target bounded');sum=sum+lv end;check(sum>1400,'Spawn-local high-level bias')
local content=require('game.custom_content');content.npcs.qa={id='qa',name='QA Elf',race='Elf',gender='female',equip_body='Wizard Robes',equip_head='Wizard Hat',eventId='regular',storyEventId='story'}
local vendor={x=400,y=400,trade='stove',shop={}};local originalShop=vendor.shop
local nw={map={authored={regionId='qa',objects={{id='skillVendor',x=400,y=400,npcDefinition='qa',questId='test_quest',eventId='regular',storyEventId='story'}}}},tradeKeepers={vendor},customNPCs={},questNPCs={},nodes={},enemies={}}
require('game.npc_bindings').apply(nw);check(vendor.race=='Elf'and vendor.equipment.body=='Wizard Robes','NPC clothing and race');check(vendor.shop==originalShop and vendor.trade=='stove','Vendor role preserved');check(vendor.questIds[1]=='test_quest','Quest assigned');check(vendor.eventId=='regular'and vendor.storyEventId=='story','Both event classes assigned')
local quests=require('quest_data');quests.quests[#quests.quests+1]={id='test_quest',title='QA Quest',objective={kind='gather',target='Pine Logs',count=1},rewards={}};nw.questNPCs=nil
local Q=require('game.quests');Q.setup(nw);local player=require('game.player').new();player.x,player.y=400,400
local skills=require('game.skills').new();local ui={world=nw,player=player,skills=skills,inv=require('game.inventory').new(),eventState={},sprites=SG_SERVER.sprites};nw.notifications={}
local E=require('game.events');E.init(ui,{entries={{id='regular',name='Regular',trigger='manual',map='*',once=false,commands={}},{id='story',name='Cutscene',trigger='manual',map='*',once=false,commands={}}}})
check(E.interact(ui,400,400,'story'),'Story outranks quest');check(E.running[1].id=='story','Correct story event')
E.init(ui,{entries={{id='regular',trigger='manual',map='*',once=false,commands={}}}});check(not E.interact(ui,400,400,'story'),'Unavailable story permits quest');check(Q.click(ui,400,400)and ui.questPanel.customQuests[1].id=='test_quest','Quest priority');ui.questPanel=nil
Q.state(player,nw.questNPCs[1]).completed=1;check(not Q.click(ui,400,400),'Completed quest allows regular event fallback')
check(E.interact(ui,400,400,'regular')and E.running[1].id=='regular','Regular event fallback');E.init(ui,{entries={{id='regular',trigger='manual',map='*',once=false,commands={}}}});check(not E.interact(ui,800,800,'regular'),'No distant NPC interaction')
return tostring(checks)..' NPC, event priority, spawn control and cave lifecycle checks passed'
"""))
finally:s.close()
