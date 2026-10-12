"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
sys.path.insert(0,str(Path(__file__).resolve().parent))
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'religion46_http_test_data';folder.mkdir(exist_ok=True)
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
sk.data.Cooking.xp=sk.xpTable[99];sk.data.Cooking.level=99;sk.data.Fieldcraft.xp=sk.xpTable[99];sk.data.Fieldcraft.level=99
local p=require('game.player').new();p.hp=10;p.maxHp=10
local a={player=p,inv=inv,skills=sk};local found=false
for y=240,w.map.height-240,160 do for x=240,w.map.width-240,160 do if not found then p.x,p.y=x,y+40;if F.valid(w,a,'Lean-to',x,y)then found=true end end end end
assert(found,'No valid wilderness footprint')
inv:add('Cover Tent',2);inv:add('Angled Timber',3);inv:add('Horizontal Timber',3);inv:add('Vertical Timber',3);inv:add('Bones',2);inv:add('Pine Logs',3);inv:add('Stone Gravel',4);inv:add('Iron Bar',20);inv:add('Oak Wood Parts',20);inv:add('Cut Emerald',3);inv:add('Raw Chicken',1);inv:add('Feather',10);inv:add('Charred Wood',100);inv:add('Tuna',1);inv:add('Shark',1);inv:add('Swordfish',1);inv:add('Manta Ray',1)
return require('game.json').encode({worldId=require('game.regions').doc.worldId,worldFingerprint=require('game.regions').networkFingerprint,regionId=require('game.regions').start,area='overworld',initial=true,seq=1,slot=1,personal=P.pack({player=p,skills=sk.data,bags=inv.bagSlots,equipment={tool='Copper Knife',weapon='Copper Longsword'},equipmentItems={tool={name='Copper Knife',qty=1,qualityGrade='A',customMark='http-preserve'},weapon={name='Copper Longsword',qty=1,qualityGrade='B'}},bank={},bankSize=25})})
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

    owner,guest=accounts;request=0
    def camp(a,cmd):
        global request
        request+=1
        status,res=http('/v1/camp',{'slot':1,'request':str(request),'revision':a['revision'],'command':cmd},a['token'])
        if status==200 and res.get('state'):
            a['revision']=res['revision'];d=unpack(res['state']);a['state']['bags']=d['bags'];a['state']['skills']=d['skills'];a['state']['bank']=d['bank']
        return status,res
    def timed(a,cmd):
        status,res=camp(a,{'op':'begin','next':cmd});assert status==200,res
        status,early=camp(a,cmd);assert status==409,early
        time.sleep(.55);status,res=camp(a,cmd);return status,res
    before=owner['state']['skills']['Religion']['xp']
    status,res=camp(owner,{'op':'bless','altar':False});assert status==200,res
    assert abs(owner['state']['skills']['Religion']['xp']-before-440)<.001
    gravel=next(it for b in owner['state']['bags'].values()for it in b['slots'].values()if it['name']=='Stone Gravel');assert not gravel.get('blessed'),'Religion 1 blessed Earth runes'
    s.eval("require('game.quality').roll=function()return 'A'end;return 'fixed-grade QA'")
    status,res=camp(guest,{'op':'carveFeather'});assert status==409,'Untimed carving accepted'
    before=guest['state']['skills']['Religion']['xp']
    for i in range(10):
        status,res=timed(guest,{'op':'carveFeather'});assert status==200,res
    feathers=[it for b in guest['state']['bags'].values()for it in b['slots'].values()if it['name']=='Carved Feather']
    assert len(feathers)==1 and feathers[0]['qty']==10 and feathers[0]['qualityGrade']=='A',feathers
    assert abs(guest['state']['skills']['Religion']['xp']-before-44)<.001
    guest['seq']+=1
    # Foreign piles are public loot, but never change their original kill credit.
    s.eval("local w=SG_SERVER.world;require('game.bone_religion').drop(w,{kind='rat',cursed=true,x="+str(guest['state']['player']['x'])+",y="+str(guest['state']['player']['y'])+",boneOwner='1:1'});return 'dropped'")
    status,poll=http('/v1/multiplayer',dict(guest['body'],seq=guest['seq'],initial=True,personal=pack(guest['state'])),guest['token']);assert status==200,poll
    ground=next(it for it in unpack(poll['snapshot'])['groundItems'].values()if it['name']=='Cursed Animal Bone Pile')
    status,res=camp(guest,{'op':'pickup','target':ground['netId']});assert status==200,res
    bi,si=next((bi,si)for bi,b in guest['state']['bags'].items()for si,it in b['slots'].items()if it['name']=='Cursed Animal Bone Pile')
    assert guest['state']['bags'][bi]['slots'][si]['boneOwner']=='1:1'
    status,res=timed(guest,{'op':'boneSeparate','bag':bi,'slot':si});assert status==200,res
    bi,si=next((bi,si)for bi,b in guest['state']['bags'].items()for si,it in b['slots'].items()if it['name'].startswith('Cursed ')and it.get('boneOwner')=='1:1')
    before=guest['state']['skills']['Religion']['xp'];status,res=timed(guest,{'op':'boneBless','bag':bi,'slot':si});assert status==409,res
    assert guest['state']['skills']['Religion']['xp']==before
    status,stored=http('/v1/characters/1',None,guest['token'],'GET');assert status==200
    d=unpack(json.loads(stored['character']['save']));assert sum(it['qty']for b in d['bags'].values()for it in b['slots'].values()if it['name']=='Carved Feather')==10
    assert service.simulation.error is None
    print('PASS authenticated per-item Religion XP, low-level rune gate, 10 timed feather casts and stacked grade-A output, foreign public pile pickup and preserved kill credit, no borrowed-bone XP, persistent state and live simulation',flush=True)
finally:
    service.shutdown();service.server_close();service.simulation.close()
