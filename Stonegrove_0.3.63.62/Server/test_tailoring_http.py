"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'tailoring_http_test_data';folder.mkdir(exist_ok=True)
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
    with closing(sqlite3.connect(db))as c:c.execute("UPDATE users SET role='admin' WHERE name='camp_owner'");c.commit()
    status,result,_=camp(owner,{'op':'admin','action':'level','skill':'Tailoring','amount':20});assert status==200,result
    for item,amount in [('Wool',1),('Wool Thread',20),('Empty Tube',3),('Large Blue Mushroom',1),('Cloth Strip',2),('Red Berries',5),('Needle',1),('Dyed Blue Cloth Strip',5)]:
        status,result,_=camp(owner,{'op':'admin','action':'give','item':item,'amount':amount});assert status==200,result
    recipes=json.loads(s.eval("local out={};for i,r in ipairs(require('game.crafting').new():getRecipes('tailoring'))do if r.tailoring then out[r.output]=i end end;return require('game.json').encode(out)"))
    def count(item):return sum(v.get('qty',1)for b in owner['state']['bags'].values()for v in b.get('slots',{}).values()if v.get('name')==item)
    def timed(item,expected=200):
        cmd={'op':'craft','station':'tailoring','index':recipes[item]}
        status,res,_=camp(owner,{'op':'begin','next':cmd});assert status==200,res
        status,res,_=camp(owner,cmd);assert status==409,'Premature completion accepted'
        time.sleep(.65)
        status,res,body=camp(owner,cmd);assert status==expected,res
        if status==200:
            before=count(item);status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==res['revision'] and count(item)==before,'Replay duplication'
        return res
    timed('Blue Dye');assert count('Blue Dye')==1 and count('Large Blue Mushroom')==0 and count('Empty Tube')==2
    timed('Red Dye');assert count('Red Dye')==1 and count('Red Berries')==0 and count('Empty Tube')==1
    timed('Wizard Robes');assert count('Wizard Robes')==1 and count('Dyed Blue Cloth Strip')==0
    before=count('Wool Thread');timed('Cloth Strip',409);assert count('Wool Thread')==before,'Distant loom consumed thread'
    x=owner['state']['player']['x'];y=owner['state']['player']['y']
    s.eval("local w=SG_SERVER.world;w.authoredObjects=w.authoredObjects or {};w.authoredObjects[#w.authoredObjects+1]={id='loom',x="+str(x)+",y="+str(y)+"};return 'ok'")
    timed('Cloth Strip');assert count('Wool Thread')==before-5 and count('Cloth Strip')==3
    timed('Dyed Blue Cloth Strip');assert count('Blue Dye')==0 and count('Dyed Blue Cloth Strip')==1 and count('Cloth Strip')==2
    status,res,_=camp(owner,{'op':'admin','action':'level','skill':'Tailoring','amount':49});assert status==200,res
    status,res,_=camp(owner,{'op':'admin','action':'give','item':'Red Cloth Strip','amount':2});assert status==200,res
    thread=count('Wool Thread');cloth=sum(count(item)for item in ('Cloth Strip','Dyed Blue Cloth Strip','Dark Blue Cloth','Red Cloth Strip','Green Cloth Strip'))
    timed('Linen Bag',409);assert count('Wool Thread')==thread and count('Linen Bag')==0,'Level49 bag changed inventory'
    status,res,_=camp(owner,{'op':'admin','action':'level','skill':'Tailoring','amount':50});assert status==200,res
    timed('Linen Bag');assert count('Linen Bag')==1 and count('Wool Thread')==thread-5 and sum(count(item)for item in ('Cloth Strip','Dyed Blue Cloth Strip','Dark Blue Cloth','Red Cloth Strip','Green Cloth Strip'))==cloth-5,'Level50 mixed cloth bag materials'
    status,record=http('/v1/characters/1',None,owner['token'],'GET');assert status==200
    persisted=unpack(json.loads(record['character']['save']));assert any(v['name']=='Wizard Robes'for b in persisted['bags'].values()for v in b.get('slots',{}).values()),'Crafted gear not durable'
    print('PASS authenticated local HTTP Tailoring: timed cast rejection, replay idempotence, dye/robe material consumption, server loom proximity, weaving/dyeing and durable inventory/XP; Linen Bag level49 rejection and level50 exact mixed-colour materials')
finally:
    service.shutdown();service.server_close();service.simulation.close();__import__('gc').collect();db.unlink();folder.rmdir()
