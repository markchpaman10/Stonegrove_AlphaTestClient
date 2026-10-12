"""Run with python Server/test_fieldcraft.py. Uses isolated data only."""
from pathlib import Path
import json
import sqlite3
import sys
import time
from types import SimpleNamespace
from contextlib import closing
from contextlib import closing
from contextlib import closing
from contextlib import closing
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack

ROOT=Path(__file__).resolve().parent.parent
simulation=Simulation(ROOT)
try:
    result=simulation.eval(r'''
local F=require('game.fieldcraft');local C=require('game.fieldcraft_content');local I=require('game.inventory');local Skills=require('game.skills');local R=require('game.rune_inventory')
local count=0;local function check(ok,message)assert(ok,message);count=count+1 end
local inv=I.new();inv.bagSlots[1].size=128;local sk=Skills.new();local p=require('game.player').new();p.x=1000;p.y=1040;p.hp=10;p.maxHp=10
local w={map={isLand=function()return true end,width=10000,height=10000},nodes={},villages={},campfires={},playerCamps={},houses={},enemies={}}
local a={player=p,inv=inv,skills=sk,campOwner='test:1'}
local craft=require('game.crafting').new()
for _,name in ipairs(C.items)do check(SG_SERVER.sprites.itemImages[name]~=nil,'Missing sprite '..name)end
check(C.tents['Cover Tent'].image==6 and C.tents['Lean-to'].image==8 and C.tents['Leather Drape Tent'].image==7,'Sprite mapping')
check(#C.tents['Cover Tent'].needs==3,'Cover must not require leaves')
inv:add('Angled Timber',1);inv:add('Horizontal Timber',1);inv:add('Vertical Timber',1)
check(craft:craft('fieldcraft',1,inv,sk,nil,nil),'Cover craft')
check(inv:countItem('Cover Tent')==1 and inv:countItem('Vertical Timber')==0,'Exact consumption')
check(not F.command(w,a,{op='deploy',tent='Lean-to',x=1000,y=1000},1),'Level gate')
local node={kind='tree',x=1000,y=1000,netId=999,depleted=true,respawnTimer=25,hp=0};w.nodes={node}
check(F.command(w,a,{op='deploy',tent='Cover Tent',x=1000,y=1000},1),'Deploy')
check(inv:countItem('Cover Tent')==0 and #w.nodes==0,'Consumption and suppression')
check(not F.command(w,a,{op='deploy',tent='Cover Tent',x=1200,y=1000},1),'One camp')
inv:add('Bones',1);local slot;for i,v in pairs(inv.bagSlots[1].slots)do if v.name=='Bones'then slot=i end end
check(F.command(w,a,{op='deposit',bag=1,slot=slot},1),'Deposit')
local ok,why=F.command(w,a,{op='pack'},1);check(not ok and why=='Empty all camp storage before packing up your camp.','Occupied storage pack guard')
check(F.command(w,a,{op='withdraw',slot=1},1),'Withdraw')
check(F.command(w,a,{op='pack'},1),'Pack')
check(inv:countItem('Cover Tent')==1 and #w.nodes==1 and w.nodes[1]==node and node.respawnTimer==25,'Exact return / resource state')
check(not F.command(w,a,{op='pack'},1)and inv:countItem('Cover Tent')==1,'Repeated pack cannot duplicate')
sk.data.Fieldcraft.xp=sk.xpTable[99];sk.data.Fieldcraft.level=99
inv:add('Leather',6);inv:add('Large Leather',2);inv:add('Rawhide String',6);inv:add('Stump Pole',2)
check(craft:craft('fieldcraft',3,inv,sk,nil,nil),'Alternate leather recipe')
check(inv:countItem('Leather')==6 and inv:countItem('Large Leather')==0,'Alternatives must not both be consumed')
check(F.command(w,a,{op='deploy',tent='Leather Drape Tent',x=1000,y=1000},1),'Leather deploy')
inv:add('Pine Logs',3);inv:add('Stone Gravel',4)
check(F.command(w,a,{op='build',structure='fire',slot=1},1),'Build')
check(#w.campfires==1,'One fire')
check(F.command(w,a,{op='layout',slot=1},1),'Layout clear')
local xp=sk.data.Fieldcraft.xp
check(F.command(w,a,{op='build',structure='fire',slot=1},1),'Restore paid construction')
check(sk.data.Fieldcraft.xp==xp and #w.campfires==1,'No repeat build XP or duplicate fire')
check(F.command(w,a,{op='rest'},1)and not F.command(w,a,{op='rest'},2),'Rest cooldown')
local c=F.owned(w,a);c.storage[1]={name='Cut Ruby',qty=1,enchantment={kind='Magic',amount=1.2}};F.remove(w,a,c,true)
check(inv:countItem('Leather Drape Tent')==0 and #w.playerCamps==0,'Logout destroys Tent and camp')
check(#a.fieldcraft.recovery==1 and a.fieldcraft.layout[1]=='fire'and a.fieldcraft.built.fire,'Recovery and layout retained')
check(F.command(w,a,{op='recover'},1)and #a.fieldcraft.recovery==0,'Recover items')
local found;for _,obj in pairs(inv.bagSlots[1].slots)do if obj.name=='Cut Ruby'then found=obj end end
check(found and found.enchantment.amount==1.2,'Stateful item metadata preserved')
local empty,reason=F.command(w,a,{op='recover'},1);check(not empty and reason=='No items to recover from lost camps.'and inv:countItem('Cut Ruby')==1,'Empty recovery idempotence')
inv:add('Cover Tent',1);check(F.command(w,a,{op='deploy',tent='Cover Tent',x=1000,y=1000},1),'Redeploy newly crafted Tent')
check(#w.campfires==1 and #F.owned(w,a).structures==1,'Saved layout rebuilt')
local intruder={player=p,inv=I.new(),skills=sk,campOwner='test:2'};check(not F.command(w,intruder,{op='withdraw',slot=1},1),'Owner-only storage')
check(C.slots(99,'Lean-to')==5 and C.structure('bank').level==99 and sk:levelForXP(sk.xpTable[99])==99,'Full progression / bank 99')
for _,name in ipairs({'Survival','Foraging','Religion'})do check(sk:get(name)~=nil,'Skill retained '..name)end
local old=sk:get('Survival').xp;p.hp=1;require('game.survival_foraging').damage(p,sk,1,'test');require('game.survival_foraging').damage(p,sk,1,'test');check(math.abs(sk:get('Survival').xp-old-sk:xpMultiplier('Survival'))<.001,'Survival encounter cooldown')
return tostring(count)..' shared Lua rule checks passed'
''')
    print(result)
    # Durable recovery and restart use a dedicated QA database under a normal
    # directory on Windows (TemporaryDirectory modes are restricted there).
    import tempfile
    folder=ROOT/'Server'/'fieldcraft_test_data'
    folder.mkdir(exist_ok=True)
    db=folder/'test.sqlite3'
    db.unlink(missing_ok=True)
    import server
    server.initialize(db)
    service=SimpleNamespace(db=str(db),simulation=None,remember_character=lambda *args:None)
    camps=Camps(service)
    config={'layout':{1:'fire'},'built':{'fire':True},'recovery':{},'active':True}
    ledger={'config':config,'xp':{'Fieldcraft':100,'Survival':2,'Foraging':4}}
    saved={'player':{'name':'Test','race':'Human'},'bags':{},'bank':{},'skills':{},'fieldcraft':config}
    item={'name':'Cut Ruby','qty':1,'enchantment':{'kind':'Magic','amount':2}}
    with closing(sqlite3.connect(db))as c:
        c.execute('INSERT INTO characters VALUES(1,1,1,?)',(json.dumps({'name':'Test','race':'Human','save':json.dumps(pack(saved))}),))
        c.execute('INSERT INTO fieldcraft VALUES(1,1,?,?,?,?)',(json.dumps(ledger),json.dumps(pack({'storage':{1:item},'tent':'Cover Tent'})),time.time(),'test-owner'));c.commit();c.commit();c.commit();c.commit();c.commit()
    camps.leave(1,'test-owner');camps.leave(1,'test-owner');camps.close()
    camps=Camps(service)
    with closing(sqlite3.connect(db))as c:
        row=c.execute('SELECT data FROM characters WHERE user=1').fetchone();out=unpack(json.loads(json.loads(row[0])['save']))
        assert len(out['fieldcraft']['recovery'])==1
        assert out['fieldcraft']['recovery'][1]['enchantment']['amount']==2
        assert out['fieldcraft']['layout'][1]=='fire'
    camps.close();__import__("gc").collect();db.unlink();folder.rmdir()
    print('PASS: durable offline logout recovery, repeated cleanup and restart; original account schema retained')
finally:
    simulation.close()
