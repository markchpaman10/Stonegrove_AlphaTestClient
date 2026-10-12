"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'skinning_http_test_data';folder.mkdir(exist_ok=True)
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
local F=require('game.fieldcraft');local P=require('game.profile');local w=SG_SERVER.world;local sk=require('game.skills').new();local inv=require('game.inventory').new();inv.bagSlots[1].size=128
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
        request+=1;body={'slot':1,'request':str(request),'revision':a['revision'],'command':command}
        status,result=http('/v1/camp',body,a['token'])
        if status==200 and result.get('state'):
            a['revision']=result['revision'];state=unpack(result['state']);a['state']['bags']=state['bags'];a['state']['skills']=state['skills'];a['state']['bank']=state['bank']
        return status,result,body
    x=owner['state']['player']['x'];y=owner['state']['player']['y']
    s.eval("local w=SG_SERVER.world;local e=require('game.zone_geometry').copy(w.enemies[1]);e.kind='cow';e.dead=true;e.skinned=false;e.hp=0;e.inactive=false;e.x="+str(x)+";e.y="+str(y)+";e.respawnTimer=3600;e.netId='qa_partial_cow';w.enemies[#w.enemies+1]=e;return 'ok'")
    def qty(state,item):return sum(v.get('qty',1)for b in state['bags'].values()for v in b.get('slots',{}).values()if v.get('name')==item)
    beforeMeat=qty(owner['state'],'Large Meat');beforeHide=qty(owner['state'],'Torn Hide')
    owner['seq']+=1;body=dict(owner['body'],seq=owner['seq'],initial=False,personal=pack(owner['state']),action={'kind':'skin','target':'qa_partial_cow','collection':'enemies'})
    status,result=http('/v1/multiplayer',body,owner['token']);assert status==200 and result['result']['ok'],result
    state=unpack(result['personal']);assert qty(state,'Large Meat')==beforeMeat+1 and qty(state,'Torn Hide')==beforeHide+1,'Wrong partial drops'
    assert result['delta']['xp']['Skinning']>0,'No reduced Skinning XP'
    status,replay=http('/v1/multiplayer',body,owner['token']);assert status==200 and replay['seq']==result['seq'],'Replay sequence'
    owner['seq']+=1;body=dict(owner['body'],seq=owner['seq'],initial=False,personal=pack(state),action={'kind':'skin','target':'qa_partial_cow','collection':'enemies'})
    status,result=http('/v1/multiplayer',body,owner['token']);assert status==200 and not result['result']['ok'],'Duplicate skin accepted'
    again=unpack(result['personal']);assert qty(again,'Large Meat')==beforeMeat+1 and qty(again,'Torn Hide')==beforeHide+1,'Duplicate items'
    guest['seq']+=1;status,result=http('/v1/multiplayer',dict(guest['body'],seq=guest['seq'],initial=True,personal=pack(guest['state'])),guest['token']);assert status==200,result
    enemy=next(e for e in unpack(result['snapshot'])['enemies'].values()if e['netId']=='qa_partial_cow');assert enemy['skinned'],'Corpse state not replicated'
    print('PASS authenticated two-account skinning HTTP: low-level cow gives exactly one meat/one Torn Hide, reduced XP, replay/idempotence, repeated corpse rejection and shared skinned state')
finally:
    service.shutdown();service.server_close();service.simulation.close();__import__('gc').collect();db.unlink();folder.rmdir()
