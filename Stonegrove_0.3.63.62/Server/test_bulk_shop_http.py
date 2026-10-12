"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
sys.path.insert(0,str(Path(__file__).resolve().parent))
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'bulk_shop_http_test_data';folder.mkdir(exist_ok=True)
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
inv:addMoney(35);inv:addItemObject({name='Rune Bag',qualityGrade='A',materials={['Fish Bones']=7},materialGrades={['Fish Bones']={A=7}}});inv:add('Cover Tent',2);inv:add('Angled Timber',3);inv:add('Horizontal Timber',3);inv:add('Vertical Timber',3);inv:add('Bones',2);inv:add('Pine Logs',3);inv:add('Stone Gravel',4);inv:add('Iron Bar',20);inv:add('Oak Wood Parts',20);inv:add('Cut Emerald',3);inv:add('Raw Chicken',1)
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
    s.eval("local w=SG_SERVER.world;w.shopkeeper.x="+str(position['x'])+";w.shopkeeper.y="+str(position['y'])+";local shop=require('game.shop').new();shop.slots={{name='Angled Timber',qty=20}};shop.buyPrice=function()return 10 end;shop.sellPrice=function()return 3 end;w.shopkeeper.shop=shop;return 'ready'")
    status,result,_=camp(owner,{'op':'buyMaterial','vendorGroup':'shopkeeper','vendorIndex':1,'slot':1,'name':'Angled Timber','qty':'all'});assert status==200,result
    after=unpack(result['state']);strings=sum(v.get('qty',1)for b in after['bags'].values()for v in b['slots'].values()if v['name']=='Angled Timber');assert strings==6
    stock=unpack(result['shopSlots']);assert stock[1]['qty']==17
    # Server permission/proximity rejection preserves quantities.
    status,rejected,_=camp(owner,{'op':'sellInventory','vendorGroup':'traders','vendorIndex':999});assert status==409,rejected
    with closing(sqlite3.connect(db))as c:c.execute("CREATE TRIGGER fail_bulk BEFORE UPDATE ON characters BEGIN SELECT RAISE(ABORT,'QA bulk shop failure'); END");c.commit()
    status,result,_=camp(owner,{'op':'sellInventory','vendorGroup':'shopkeeper','vendorIndex':1});assert status==500,result
    with closing(sqlite3.connect(db))as c:c.execute('DROP TRIGGER fail_bulk');c.commit()
    info=s.call('admin_info',{'id':1,'slot':1});assert info['ok']
    live=unpack(info['personal']);assert sum(v.get('qty',1)for b in live['bags'].values()for v in b['slots'].values()if v['name']=='Angled Timber')==6
    assert json.loads(s.eval("return require('game.json').encode(SG_SERVER.world.shopkeeper.shop.slots[1].qty)"))==17
    status,result,body=camp(owner,{'op':'sellInventory','vendorGroup':'shopkeeper','vendorIndex':1});assert status==200,result
    after=unpack(result['state']);goods=[v for b in after['bags'].values()for v in b['slots'].values()];assert not any(v['name']=='Angled Timber'for v in goods)
    assert any(v['name']=='Rune Bag'and v['materials']['Fish Bones']==7 for v in goods)
    assert any(v['name']=='Cover Tent'for v in goods)
    status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==result['revision']
    status,record=http('/v1/characters/1',None,owner['token'],'GET');assert status==200;assert unpack(json.loads(record['character']['save']))['bags']==after['bags']
    print('PASS authenticated bulk buy/sell, affordability, containers, proximity, replay, durable inventory and forced-write rollback')
finally:
    service.shutdown();service.server_close();__import__('gc').collect();db.unlink();folder.rmdir()
