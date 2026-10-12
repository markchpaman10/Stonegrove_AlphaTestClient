"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'shellfish_balance_http_test_data';folder.mkdir(exist_ok=True)
db=folder/'test.sqlite3';db.unlink(missing_ok=True);server.initialize(db)
for name in ('camp_owner','camp_guest'):server.create_user(db,name,'qa_password_123')
service=server.Service(('127.0.0.1',0),db);service.simulation=Simulation(root);service.camps=Camps(service)
threading.Thread(target=service.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{service.server_port}'
def http(path,data=None,token=None,method='POST'):
    req=urllib.request.Request(base+path,data=json.dumps(data).encode()if data is not None else None,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
    try:
        with urllib.request.urlopen(req,timeout=30)as r:return r.status,json.load(r)
    except urllib.error.HTTPError as e:return e.code,json.load(e)
keepalive=threading.Event()
try:
    s=service.simulation
    fixture=json.loads(s.eval(r'''
local F=require('game.fieldcraft');local P=require('game.profile');local w=SG_SERVER.world;local sk=require('game.skills').new();local inv=require('game.inventory').new();inv.bagSlots[1].size=128
sk.data.Fieldcraft.xp=sk.xpTable[99];sk.data.Fieldcraft.level=99
local p=require('game.player').new();p.hp=10;p.maxHp=10
local a={player=p,inv=inv,skills=sk};local found=false
for y=240,w.map.height-240,160 do for x=240,w.map.width-240,160 do if not found then p.x,p.y=x,y+40;if F.valid(w,a,'Lean-to',x,y)then found=true end end end end
assert(found,'No valid wilderness footprint');p.x,p.y=w.shopkeeper.x,w.shopkeeper.y
sk.data.Fishing.xp=sk.xpTable[99];sk.data.Fishing.level=99;sk.data.Cooking.xp=sk.xpTable[30];sk.data.Cooking.level=30;inv:add('Shrimp Pot',1);inv:add('Flint and Steel',1);inv:add('Pine Logs',20);sk.data.Firemaking.level=10;sk.data.Firemaking.xp=sk.xpTable[10];inv:add('Crab Pot',1);inv:add('Lobster Pot',1);inv:add('Crab',1);inv:add('Lobster',1);inv:add('Cooked Crab Meat A',2);w.map.isBeachCell=function()return true end;w.map.isBeachWaterCell=function()return true end;inv:add('Cover Tent',2);inv:add('Angled Timber',3);inv:add('Horizontal Timber',3);inv:add('Vertical Timber',3);inv:add('Bones',2);inv:add('Pine Logs',3);inv:add('Stone Gravel',4);inv:add('Iron Bar',20);inv:add('Oak Wood Parts',20);inv:add('Cut Emerald',3);inv:add('Raw Chicken',1)
return require('game.json').encode({worldId=require('game.regions').doc.worldId,worldFingerprint=require('game.regions').networkFingerprint,regionId=require('game.regions').start,area='overworld',initial=true,seq=1,slot=1,personal=P.pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={},potionBelt={[1]='Cooked Crab Meat A'},bank={},bankSize=25})})
'''))
    accounts=[]
    for name in ('camp_owner','camp_guest'):
        status,user=http('/v1/login',{'name':name,'password':'qa_password_123'});assert status==200
        token=user['token'];state=unpack(fixture['personal']);state['player']['name']=name
        if name=='camp_guest':state['player']['x']+=200
        clean=dict(state,bags={},skills={});record={'name':name,'race':'Human','save':json.dumps(pack(clean))}
        status,saved=http('/v1/characters/1',{'revision':0,'character':record},token,'PUT');assert status==200
        with closing(sqlite3.connect(db))as c:
            uid=c.execute('SELECT id FROM users WHERE name=?',(name,)).fetchone()[0]
            record['save']=json.dumps(pack(state));c.execute('UPDATE characters SET data=? WHERE user=? AND slot=1',(json.dumps(record),uid))
            ledger={'config':{'layout':{},'built':{},'recovery':{},'regions':{}},'xp':{'Fieldcraft':state['skills']['Fieldcraft']['xp'],'Survival':0,'Foraging':0}}
            c.execute("INSERT OR REPLACE INTO fieldcraft(user,slot,data,active,seen,owner)VALUES(?,1,?,'',0,'')",(uid,json.dumps(ledger)));c.commit()
        body=dict(fixture,personal=pack(state));status,result=http('/v1/multiplayer',body,token);assert status==200,result
        accounts.append({'token':token,'revision':1,'seq':1,'state':state,'body':body})
    owner,guest=accounts;position=dict(owner['state']['player']);position['y']-=40;request=0
    def camp(a,command):
        global request
        request+=1;body={'slot':1,'request':str(request),'revision':a['revision'],'command':command}
        status,result=http('/v1/camp',body,a['token'])
        if status==200 and result.get('state'):
            a['revision']=result['revision'];state=unpack(result['state']);a['state']['bags']=state['bags'];a['state']['skills']=state['skills'];a['state']['bank']=state['bank']
        return status,result,body


    def ping():
        while not keepalive.wait(1):
            for account in accounts:http('/v1/camp/ping',{'slot':1},account['token'])
    threading.Thread(target=ping,daemon=True).start()
    def count(name):return sum(v.get('qty',1)for b in owner['state']['bags'].values()for v in b.get('slots',{}).values()if v and v.get('name')==name)
    def locate(name):
        for bi,b in owner['state']['bags'].items():
            for si,v in b.get('slots',{}).items():
                if v and v.get('name')==name:return int(bi),int(si)
    def timed(cmd):
        status,res,_=camp(owner,{'op':'begin','next':cmd});assert status==200,res;assert res['duration']==2
        status,res,_=camp(owner,cmd);assert status==409,res
        time.sleep(2.05);status,res,body=camp(owner,cmd);assert status==200,res
        status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==res['revision']
        return res
    bi,si=locate('Crab Pot');pos=owner['state']['player'];cmd=dict(op='potPlace',bag=bi,slot=si,name='Crab Pot',x=pos['x'],y=pos['y']);timed(cmd);assert count('Crab Pot')==0
    status,res,_=camp(guest,{'op':'potRecover','id':'invalid'});assert status==409
    s.eval("local w=SG_SERVER.world;assert(#w.shellfishPots==1);w.shellfishPots[1].catchCount=10;return 'ready'")
    pot=json.loads(s.eval("return require('game.json').encode(SG_SERVER.world.shellfishPots[1])"))
    restored=Simulation(root)
    try:
        restored.call('restore',s.call('export',{}));reply=restored.call('exchange',dict(fixture,id=999,owner='checkpoint_qa'))
        pots=unpack(reply['snapshot'])['shellfishPots'];values=pots.values()if isinstance(pots,dict)else pots;loaded=list(values);assert len(loaded)==0,'Restart must not restore abandoned pots'
    finally:restored.close()
    timed({'op':'potRecover','id':pot['id']});assert count('Crab Pot')==1
    bi,si=locate('Crab Pot');status,res,body=camp(owner,dict(op='potEmpty',bag=bi,slot=si));assert status==200,res
    status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==res['revision']
    assert json.loads(s.eval("local n=0;for _,v in ipairs(SG_SERVER.world.groundItems)do if v.name=='Crab'then n=n+1 end end;return tostring(n)"))==10
    status,res,_=camp(owner,dict(op='potEmpty',bag=bi,slot=si));assert status==409
    # New Shrimp pot uses the same timed protected transaction and replay rules.
    bi,si=locate('Shrimp Pot');timed(dict(op='potPlace',bag=bi,slot=si,name='Shrimp Pot',x=pos['x'],y=pos['y']))
    s.eval("local p=SG_SERVER.world.shellfishPots[1];p.catchCount=4;return 'ready'")
    shrimp=json.loads(s.eval("return require('game.json').encode(SG_SERVER.world.shellfishPots[1])"))
    fishing_before=owner['state']['skills']['Fishing']['xp'];timed(dict(op='potRecover',id=shrimp['id']))
    assert abs(owner['state']['skills']['Fishing']['xp']-fishing_before-44)<.001
    bi,si=locate('Shrimp Pot');status,res,_=camp(owner,dict(op='potEmpty',bag=bi,slot=si));assert status==200,res
    assert json.loads(s.eval("local n=0;for _,v in ipairs(SG_SERVER.world.groundItems)do if v.name=='Shrimp'then n=n+1 end end;return tostring(n)"))==4
    # Online fires remain in the shared world and grant a buff with a real expiry.
    s.eval("SG_SERVER.world.campfires={};return 'ready'")
    logs_before=count('Pine Logs');timed(dict(op='fireCreate',fuel='Pine Logs'));assert count('Pine Logs')==logs_before-1
    fire=json.loads(s.eval("local f=SG_SERVER.world.campfires[1];assert(f.bonfire and f.timer<=20);f.netId=999994;return require('game.json').encode(f)"))
    res=timed(dict(op='fireRefuel',fuel='Pine Logs',fireId=fire['netId']));assert count('Pine Logs')==logs_before-2
    assert json.loads(s.eval("return tostring(SG_SERVER.world.campfires[1].queuedLogs)"))==1
    assert unpack(res['state'])['status']['bonfireBuffUntil']>time.time(),'Temporary buff missing'
    # Inject a failed durable write after refuelling, and retry the exact receipt.
    cmd=dict(op='fireRefuel',fuel='Pine Logs',fireId=fire['netId']);status,res,_=camp(owner,dict(op='begin',next=cmd));assert status==200,res
    time.sleep(2.05)
    with closing(sqlite3.connect(db))as c:c.execute("CREATE TRIGGER qa_fail_update BEFORE UPDATE ON characters BEGIN SELECT RAISE(ABORT,'QA forced fire write failure'); END");c.commit()
    before=count('Pine Logs');status,res,failed_body=camp(owner,cmd);assert status==500,res
    assert json.loads(s.eval("return tostring(SG_SERVER.world.campfires[1].queuedLogs)"))==1,'Failed fuel write changed queue'
    with closing(sqlite3.connect(db))as c:c.execute('DROP TRIGGER qa_fail_update');c.commit()
    status,res=http('/v1/camp',failed_body,owner['token']);assert status==200,res;owner['revision']=res['revision'];state=unpack(res['state']);owner['state']['bags']=state['bags'];owner['state']['skills']=state['skills'];owner['state']['bank']=state['bank'];assert count('Pine Logs')==before-1
    for species in ('Crab','Lobster'):
        bi,si=locate(species);before=count(species+' Meat');timed(dict(op='shellFillet',bag=bi,slot=si));assert count(species+' Meat')==before
        pbi,psi=locate(species+' Parts');assert (pbi,psi)==(bi,si)
        assert json.loads(s.eval("return tostring(#SG_SERVER.world.shellfishParts)"))==0
        timed(dict(op='shellHarvest',bag=bi,slot=si));assert 1<=count(species+' Meat')-before<=5
    s.eval("for _,a in ipairs(SG_SERVER.world.onlineActors or{})do a.player.hp=1;a.player.maxHp=200 end;return 'ready'")
    status,res,body=camp(owner,dict(op='beltFood',slot=1));assert status==200,res;assert unpack(res['state'])['potionBelt']=={}
    status,res,_=camp(owner,dict(op='beltFood',slot=1));assert status==409
    status,stored=http('/v1/characters/1',token=owner['token'],method='GET');assert status==200
    saved=unpack(json.loads(stored['character']['save']));assert saved['bags']==owner['state']['bags']and saved['potionBelt']=={}
    # Pot payload forgery must fail ordinary saves without changing stored catch data.
    for bag in saved['bags'].values():
        for obj in bag.get('slots',{}).values():
            if obj and obj['name']=='Crab Pot':obj['catchCount']=10
    record=dict(stored['character'],save=json.dumps(pack(saved)));status,res=http('/v1/characters/1',{'revision':owner['revision'],'character':record},owner['token'],'PUT');assert status==400,res
    checkpoint=s.call('export',{});assert checkpoint
    bi,si=locate('Crab Pot');timed(dict(op='potPlace',bag=bi,slot=si,name='Crab Pot',x=pos['x'],y=pos['y']))
    ground=json.loads(s.eval("return tostring(#SG_SERVER.world.groundItems)"))
    assert json.loads(s.eval("return tostring(#SG_SERVER.world.shellfishPots)"))==1
    status,res=http('/v1/logout',{},owner['token']);assert status==200,res
    assert json.loads(s.eval("return tostring(#SG_SERVER.world.shellfishPots)"))==0
    assert json.loads(s.eval("return tostring(#SG_SERVER.world.groundItems)"))==ground,'Public catches removed on logout'
    with closing(sqlite3.connect(db))as c:
        rows=c.execute('SELECT data FROM fieldcraft').fetchall();assert all(not json.loads(row[0])['config'].get('pots')for row in rows)
    print('PASS real authenticated Shrimp pot, per-catch XP, shared fires, refuel replay, forced fuel-write rollback/retry, temporary buff and shellfish HTTP: timed placement/recovery/fillet/harvest, early rejection, exact yields, replay, empty ground drops, belt food, durable save and catch forgery rejection')
finally:
    keepalive.set()
    service.shutdown();service.server_close()
