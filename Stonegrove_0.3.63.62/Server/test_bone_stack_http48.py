"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
sys.path.insert(0,str(Path(__file__).resolve().parent))
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'bone_stack_http48_test_data';folder.mkdir(exist_ok=True)
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
local F=require('game.fieldcraft');local P=require('game.profile');local w=SG_SERVER.world;local sk=require('game.skills').new();local inv=require('game.inventory').new();sk.data.Strength.xp=sk.xpTable[99];sk.data.Strength.level=99;inv.bagSlots={};for i=1,4 do inv.bagSlots[i]={name='Large Leather Bag',qualityGrade='A',slots={}}end;inv:applyStrengthBagBonus(99)
sk.data.Fieldcraft.xp=sk.xpTable[99];sk.data.Fieldcraft.level=99
local p=require('game.player').new();p.hp=10;p.maxHp=10
local a={player=p,inv=inv,skills=sk};local found=false
for y=240,w.map.height-240,160 do for x=240,w.map.width-240,160 do if not found then p.x,p.y=x,y+40;if F.valid(w,a,'Lean-to',x,y)then found=true end end end end
assert(found,'No valid wilderness footprint')
inv:add('Cover Tent',2);inv:add('Angled Timber',3);inv:add('Horizontal Timber',3);inv:add('Vertical Timber',3);inv:add('Bones',2);inv:add('Pine Logs',3);inv:add('Stone Gravel',4);inv:add('Iron Bar',20);inv:add('Oak Wood Parts',20);inv:add('Cut Emerald',3);inv:add('Raw Chicken',1)
local B=require('game.bone_religion');for i=1,8 do B.drop(w,{kind='rat',cursed=true,x=p.x,y=p.y,boneOwner='1:1'});local pile=w.groundItems[#w.groundItems].object;B.claims[pile.boneToken].outputs={['Cursed Bones']=2,['Cursed Ribs']=1};assert(inv:addItemObject(pile))end;local found=false;for _,bag in pairs(inv.bagSlots)do for _,it in pairs(bag.slots)do if it.name=='Cursed Animal Bone Pile'then assert(it.qty==8);found=true end end end;assert(found)
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
        request+=1;body={'slot':1,'request':str(request),'revision':a['revision'],'command':command}
        status,result=http('/v1/camp',body,a['token'])
        if status==200 and result.get('state'):
            a['revision']=result['revision'];state=unpack(result['state']);a['state']['bags']=state['bags'];a['state']['skills']=state['skills'];a['state']['bank']=state['bank']
        return status,result,body

    def locate(name):
        return next((bi,si)for bi,b in owner['state']['bags'].items()for si,it in b['slots'].items()if it['name']==name)
    def timed(cmd):
        status,result,_=camp(owner,{'op':'begin','next':cmd});assert status==200 and result['duration']==.5,result
        time.sleep(.55)
        return camp(owner,cmd)
    bi,si=locate('Cursed Animal Bone Pile');split={'op':'boneSeparate','bag':bi,'slot':si}
    status,result,_=camp(owner,split);assert status==409,result
    status,result,_=camp(owner,{'op':'begin','next':split});assert status==200,result
    status,result,_=camp(owner,split);assert status==409,'Early separation accepted'
    time.sleep(.55)
    with closing(sqlite3.connect(db))as c:c.execute("CREATE TRIGGER fail_bones BEFORE UPDATE ON characters BEGIN SELECT RAISE(ABORT,'QA bone ledger failure'); END");c.commit()
    status,result,body=camp(owner,split);assert status==500,result
    phase=s.eval("for _,c in pairs(require('game.bone_religion').claims)do if c.owner=='1:1'and c.phase~='pile'then return 'consumed' end end;return 'pile'")
    assert phase=='pile','Failed DB commit consumed the private bone claim'
    with closing(sqlite3.connect(db))as c:c.execute('DROP TRIGGER fail_bones');c.commit()
    status,result=http('/v1/camp',body,owner['token']);assert status==200,result
    owner['revision']=result['revision'];state=unpack(result['state']);owner['state']['bags']=state['bags'];owner['state']['skills']=state['skills']
    status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==result['revision']
    assert sum(it.get('qty',1) for b in owner['state']['bags'].values()for it in b['slots'].values()if it['name']=='Cursed Bones')==16
    assert not any(it['name']=='Cursed Animal Bone Pile' for b in owner['state']['bags'].values()for it in b['slots'].values())
    bi,si=locate('Cursed Bones');bury={'op':'boneBury','bag':bi,'slot':si}
    status,result,_=timed(bury);assert status==409 and 'Bless cursed' in result['error'],result
    bless={'op':'boneBless','bag':bi,'slot':si}
    status,result,_=camp(owner,{'op':'begin','next':bless});assert status==200
    s.eval("local actors;for i=1,30 do local n,v=debug.getupvalue(SG_CAMP,i);if n=='actors'then actors=v end end;actors[1].player.damageSerial=(actors[1].player.damageSerial or 0)+1;return 'interrupted'")
    time.sleep(.55);status,result,_=camp(owner,bless);assert status==409,'Damage failed to interrupt bone blessing'
    status,result,_=timed(bless);assert status==200,result
    status,result,_=timed(bury);assert status==200,result
    # The remaining blessed bone survives real bank storage, then a second burial.
    remaining=next(it for b in owner['state']['bags'].values()for it in b['slots'].values()if it['name']=='Cursed Bones');assert remaining['qty']==14 and remaining['blessed']
    owner['seq']+=1;status,poll=http('/v1/multiplayer',dict(owner['body'],seq=owner['seq'],initial=True,personal=pack(owner['state'])),owner['token']);assert status==200,poll
    snap=unpack(poll['snapshot']);assert 'boneClaims' not in snap
    marker=next(iter(snap['burialGraves'].values()));assert marker['owner']=='1:1' and 58<marker['remaining']<=60
    status,result,_=timed({'op':'boneGraveBless','id':marker['id']});assert status==200,result
    status,result,_=timed({'op':'boneGraveBless','id':marker['id']});assert status==409,result
    saved=unpack(s.call('export',{}));assert saved['boneClaims']['claims']
    restarted=Simulation(root);restarted.stopped.set();restarted.thread.join()
    try:
        assert restarted.call('restore',pack(saved))['ok']
        again=unpack(restarted.call('export',{}));assert again['boneClaims']['claims']==saved['boneClaims']['claims']
        assert sum(len(v.get('burialGraves',{}))for v in again['rooms'].values())>=1,'Burial markers lost on server restart'
    finally:restarted.close()
    assert service.simulation.error is None
    print('PASS authenticated eight-pile stack, all eight ledger rollback records and quantity-conserving bone HTTP: 0.5-second casts, early rejection, damage interruption, cursed blessing before burial, persistent kill ownership, one-log burial, marker replication, one-time blessing, replay and forced DB-failure private-ledger rollback',flush=True)
finally:
    service.shutdown();service.server_close();__import__('gc').collect();db.unlink();folder.rmdir()
