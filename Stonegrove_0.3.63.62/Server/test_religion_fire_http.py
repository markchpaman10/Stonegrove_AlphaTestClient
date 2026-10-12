"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'religion_fire_http_test_data';folder.mkdir(exist_ok=True)
db=folder/'test.sqlite3';db.unlink(missing_ok=True);server.initialize(db)
for name in ('camp_owner','camp_guest'):server.create_user(db,name,'qa_password_123')
service=server.Service(('127.0.0.1',0),db);service.simulation=Simulation(root);service.camps=Camps(service)
threading.Thread(target=service.serve_forever,daemon=True).start();base=f'http://127.0.0.1:{service.server_port}'
def http(path,data=None,token=None,method='POST'):
    req=urllib.request.Request(base+path,data=json.dumps(data).encode()if data is not None else None,method=method,headers={'Content-Type':'application/json',**({'Authorization':'Bearer '+token}if token else{})})
    try:
        with urllib.request.urlopen(req,timeout=30)as r:return r.status,json.load(r)
    except urllib.error.HTTPError as e:return e.code,json.load(e)
try:
    s=service.simulation
    fixture=json.loads(s.eval(r'''
local F=require('game.fieldcraft');local P=require('game.profile');local w=SG_SERVER.world;w.enemies={};w.updateCombat=function()end;local sk=require('game.skills').new();local inv=require('game.inventory').new();sk.data.Strength.xp=sk.xpTable[99];sk.data.Strength.level=99;inv.bagSlots={};for i=1,4 do inv.bagSlots[i]={name='Large Leather Bag',qualityGrade='A',slots={}}end;inv:applyStrengthBagBonus(99)
sk.data.Fieldcraft.xp=sk.xpTable[99];sk.data.Fieldcraft.level=99
local p=require('game.player').new();p.hp=10;p.maxHp=10
local a={player=p,inv=inv,skills=sk};local found=false
for y=240,w.map.height-240,160 do for x=240,w.map.width-240,160 do if not found then p.x,p.y=x,y+40;if F.valid(w,a,'Lean-to',x,y)then found=true end end end end
assert(found,'No valid wilderness footprint')
inv:add('Cover Tent',2);inv:add('Angled Timber',3);inv:add('Horizontal Timber',3);inv:add('Vertical Timber',3);inv:add('Bones',2);inv:add('Pine Logs',3);inv:add('Stone Gravel',4);inv:add('Iron Bar',20);inv:add('Oak Wood Parts',20);inv:add('Cut Emerald',3);inv:add('Raw Chicken',1)
return require('game.json').encode({worldId=require('game.regions').doc.worldId,worldFingerprint=require('game.regions').networkFingerprint,regionId=require('game.regions').start,area='overworld',initial=true,seq=1,slot=1,personal=P.pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={},bank={},bankSize=25})})
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
        for peer in accounts:
            status,ping=http('/v1/camp/ping',{'slot':1},peer['token']);assert status==200,ping
        request+=1;body={'slot':1,'request':str(request),'revision':a['revision'],'command':command}
        status,result=http('/v1/camp',body,a['token'])
        if status==200 and result.get('state'):
            a['revision']=result['revision'];state=unpack(result['state']);a['state']['bags']=state['bags'];a['state']['skills']=state['skills'];a['state']['bank']=state['bank']
        return status,result,body
    with closing(sqlite3.connect(db))as c:c.execute("UPDATE users SET role='admin' WHERE name='camp_owner'");c.commit()
    for name,qty in [('Charred Wood',3),('Feather',2),('Copper Knife',1),('Flint and Steel',1),('Pine Logs',3),('Poplar Logs',3)]:
        status,result,_=camp(owner,dict(op='admin',action='give',item=name,amount=qty));assert status==200,result
    status,result,_=camp(owner,dict(op='admin',action='level',skill='Firemaking',amount=10));assert status==200,result
    status,result,_=camp(owner,dict(op='admin',action='level',skill='Religion',amount=3));assert status==200,result
    before=owner['state']['skills']['Religion']['xp'];status,result,body=camp(owner,dict(op='bless',altar=False));assert status==200,result
    gained=owner['state']['skills']['Religion']['xp']-before;assert abs(gained-30.8)<.001,(gained,owner['state']['skills']['Religion'])
    status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==owner['revision']
    status,result,_=camp(owner,dict(op='bless',altar=False));assert status==409
    status,result,_=camp(owner,dict(op='begin',next={'op':'carveFeather'}));assert status==200,result
    time.sleep(.55)
    status,result,_=camp(owner,dict(op='carveFeather'));assert status==200,result
    xp=owner['state']['skills']['Religion']['xp'];assert abs(xp-before-35.2)<.001
    owner['seq']+=1;status,result=http('/v1/multiplayer',dict(owner['body'],seq=owner['seq'],initial=False,personal=pack(owner['state'])),owner['token']);assert status==200,result
    status,stored=http('/v1/characters/1',None,owner['token'],'GET');assert status==200;assert abs(unpack(json.loads(stored['character']['save']))['skills']['Religion']['xp']-xp)<.001
    status,result,_=camp(owner,dict(op='bless',altar=True));assert status==409,'Remote altar must fail'
    def timed(cmd):
        status,result,_=camp(owner,dict(op='begin',next=cmd));assert status==200,result
        status,result,_=camp(owner,cmd);assert status==409,'Early cast must fail'
        time.sleep(2.1);status,result,body=camp(owner,cmd);assert status==200,result
        return result,body
    result,body=timed(dict(op='fireCreate',fuel='Pine Logs'))
    fire=json.loads(s.eval("local w=SG_SERVER.world;for _,f in ipairs(w.campfires)do if f.bonfire then return require('game.json').encode(f)end end;error('No bonfire')"));assert fire['timer']>0
    owner['seq']+=1;status,result=http('/v1/multiplayer',dict(owner['body'],seq=owner['seq'],initial=True,personal=pack(owner['state'])),owner['token']);assert status==200,result
    fire=json.loads(s.eval("for _,f in ipairs(SG_SERVER.world.campfires)do if f.bonfire then return require('game.json').encode(f)end end"));assert fire.get('netId')
    result,body=timed(dict(op='fireRefuel',fuel='Poplar Logs',fireId=fire['netId']))
    status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==owner['revision']
    assert json.loads(s.eval("for _,f in ipairs(SG_SERVER.world.campfires)do if f.bonfire then return require('game.json').encode({logs=f.burnedLogs,queued=f.queuedLogs})end end"))['logs']==2
    status,stored=http('/v1/characters/1',None,owner['token'],'GET');assert status==200;state=unpack(json.loads(stored['character']['save']));assert state['player']['bonfireBuffUntil']>time.time();assert abs(state['skills']['Religion']['xp']-xp)<.001
    # A failed database commit must roll back consumed feathers AND protected XP.
    before=owner['state']['skills']['Religion']['xp']
    status,result,_=camp(owner,dict(op='begin',next={'op':'carveFeather'}));assert status==200,result
    time.sleep(.55)
    with closing(sqlite3.connect(db))as c:c.execute("CREATE TRIGGER religion_qa_fail BEFORE UPDATE ON characters BEGIN SELECT RAISE(ABORT,'QA forced Religion write failure'); END");c.commit()
    status,result,_=camp(owner,dict(op='carveFeather'));assert status==500,result
    with closing(sqlite3.connect(db))as c:c.execute('DROP TRIGGER religion_qa_fail');c.commit()
    status,result,_=camp(owner,dict(op='carveFeather'));assert status==200,result
    assert abs(owner['state']['skills']['Religion']['xp']-before-4.4)<.001,'Failed write must not duplicate XP'
    owner['seq']+=1;status,result=http('/v1/multiplayer',dict(owner['body'],seq=owner['seq'],initial=False,personal=pack(owner['state'])),owner['token']);assert status==200,result
    status,stored=http('/v1/characters/1',None,owner['token'],'GET');assert status==200;assert abs(unpack(json.loads(stored['character']['save']))['skills']['Religion']['xp']-before-4.4)<.001
    print('PASS authenticated blessing/carving XP, durable character save, multiplayer exchange, replay/duplicate guards, Religion database-failure rollback, remote altar gate, timed bonfire creation and Poplar refuel')
finally:
    service.shutdown();service.server_close();service.simulation.close();__import__('gc').collect();db.unlink();folder.rmdir()
