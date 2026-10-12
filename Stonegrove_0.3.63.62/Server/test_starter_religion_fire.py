from pathlib import Path
from simulation import Simulation
s=Simulation(Path(__file__).resolve().parent.parent);s.stopped.set();s.thread.join()
try:
 print(s.eval(r'''
local I=require('game.inventory');local P=require('game.profile');local J=require('game.json');local Regions=require('game.regions');local Religion=require('game.religion');local checks=0
local function check(v,msg)assert(v,msg or('Regression check '..(checks+1)));checks=checks+1 end
local inv=I.new();check(inv:usedSlots()==0,'Starter inventory must be empty');local want={'Copper Axe','Copper Pickaxe','Copper Knife','Copper Dagger','Copper Hammer','Copper Tongs','Copper Longsword','Copper Shield'};check(inv:bankUsed()==8);for _,name in ipairs(want)do local count=0;for _,v in pairs(inv.bank)do if v.name==name then count=count+(v.qty or 1)end end;check(count==1,name);check(inv:countItem(name)==0,name)end
local copy=P.unpack(P.pack({bags=inv.bagSlots,bank=inv.bank}));check(copy.bank[7].name=='Copper Longsword'and not next(copy.bags[1].slots))
local w=SG_SERVER.world;local sk=require('game.skills').new();local p=require('game.player').new();p.x,p.y=500,500
inv:add('Copper Knife',1);inv:add('Feather',2);inv:addItemObject({name='Charred Wood',qualityGrade='A',qty=3});local state={player=p,skills=sk.data,bags=inv.bagSlots,bank=inv.bank,equipment={},fieldcraft={}}
local b={id=880,slot=1,owner='regression',name='Regression',race='Human',worldId=Regions.doc.worldId,regionId=Regions.start,area='overworld',initial=true,seq=1,personal=P.pack(state)};SG_CALL('exchange',J.encode(b))
local function command(cmd)local reply=SG_CAMP('camp_command',{id=b.id,slot=1,owner=b.owner,command=cmd,saved=P.pack(state)});if reply.ok and reply.state then local d=P.unpack(reply.state);for _,k in ipairs({'bags','bank','bankSize','skills','fieldcraft'})do state[k]=d[k]end end;return reply end
check(command({op='bless',altar=false}).ok);check(math.abs(state.skills.Religion.xp-13.2)<.001);check(state.bags[1].slots[3].qualityGrade=='A'and state.bags[1].slots[3].blessed);local before=state.skills.Religion.xp;check(not command({op='bless',altar=false}).ok);check(state.skills.Religion.xp==before)
check(command({op='begin',next={op='carveFeather'}}).ok);local realNow=love.timer.getTime;love.timer.getTime=function()return realNow()+.6 end;check(command({op='carveFeather'}).ok);love.timer.getTime=realNow;check(math.abs(state.skills.Religion.xp-17.6)<.001)
b.seq=2;b.initial=false;b.personal=P.pack(state);local reply=J.decode(SG_CALL('exchange',J.encode(b)));check(reply.skillTotals.Religion==nil or reply.skillTotals.Religion==16);local exported=J.decode(SG_CALL('export','{}'));check(exported~=nil)
-- An action returning personal state must retain the server Religion total.
b.seq=3;b.action={kind='spell',slot=1};reply=J.decode(SG_CALL('exchange',J.encode(b)));local actual=P.unpack(reply.personal);check(math.abs(actual.skills.Religion.xp-17.6)<.001,'XP must survive exchange, not reset to zero')
check(not command({op='bless',altar=true}).ok,'Remote altar blocked')
local st={x=600,y=600};w.villages[#w.villages+1]={cx=600,cy=600,religionAltar=st};check(st~=nil);state.player.x,state.player.y=st.x,st.y;b.seq=4;b.action=nil;b.personal=P.pack(state);SG_CALL('exchange',J.encode(b));state.bags[1].slots[4]={name='Charred Wood',qty=30};check(command({op='bless',altar=true}).ok);check(math.abs(state.skills.Religion.xp-281.6)<.001,'Altar awards XP for all 30 items')
local U=require('game.ui');local u=setmetatable({inv=inv,skills=sk,equipment={},sprites=SG_SERVER.sprites,world=w,player=p,open={}},{__index=U});local options=u:contextOptions({name='Pine Logs'});local has=false;for _,v in ipairs(options)do if v=='Add to Bonfire'then has=true end end;check(has,'Log action stays visible without nearby fire');local ok,why=require('game.bonfire_ui').start(u,'Pine Logs');check(not ok and why=='Firemaking level 10 required')
local F=require('game.fire_fuel');local oldNow=F.now;local clock=1000;F.now=function()return clock end
local fireInv=I.new();fireInv:add('Flint and Steel',1);fireInv:add('Pine Logs',2);fireInv:add('Poplar Logs',2);local fireSkills=require('game.skills').new();fireSkills.data.Firemaking.xp=fireSkills.xpTable[10];fireSkills.data.Firemaking.level=10;local fp=require('game.player').new();local land=false;for y=200,w.map.height-200,80 do for x=200,w.map.width-200,80 do if not land and w.map:isLand(x+18,y+8)and not w:bonfireNear({x=x,y=y})then fp.x,fp.y=x,y;land=true end end end;check(land);local oldFires=w.campfires;w.campfires={}
check(w:createCampfire(fp,fireInv,fireSkills,nil,'Pine Logs'));local f=w.campfires[1];check(f.bonfire and f.timer==20);check(require('game.bonfire_buff').active(fp));local originalUntil=fp.bonfireBuffUntil;fp.x=fp.x+100;check(not w:bonfireNear(fp));check(require('game.bonfire_buff').active(fp),'Buff persists away');fp.x=fp.x-100;clock=1002;check(w:addBonfireLog(fp,fireInv,fireSkills,nil,'Poplar Logs',f));check(f.queuedLogs==1 and f.timer==18);check(fp.bonfireBuffUntil>originalUntil);clock=1020;F.realtime(w,fp);check(#w.campfires==1 and f.completedLogs==1);clock=1040;F.realtime(w,fp);check(#w.campfires==0);check(require('game.bonfire_buff').active(fp));clock=1303;check(not require('game.bonfire_buff').active(fp));F.now=oldNow;w.campfires=oldFires
check(require('game.help').stations.religionAltar[1]=='Religion Altar')
return 'PASS '..checks..' starter, Religion XP persistence, altar, log menu, bonfire fuel and timed buff regression checks'
'''))
finally:s.close()
