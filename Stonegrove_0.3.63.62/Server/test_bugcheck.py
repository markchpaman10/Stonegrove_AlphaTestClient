"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'material_sale_test_data';folder.mkdir(exist_ok=True)
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
assert(found,'No valid wilderness footprint');p.x,p.y=w.shopkeeper.x,w.shopkeeper.y
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

    def count(name):return sum(v.get('qty',1)for b in owner['state']['bags'].values()for v in b.get('slots',{}).values()if v and v.get('name')==name)
    def locate(name):
        for bi,b in owner['state']['bags'].items():
            for si,v in b.get('slots',{}).items():
                if v and v.get('name')==name:return int(bi),int(si)
    def sell(name,all=False,group='shopkeeper',index=1):
        bi,si=locate(name)
        return camp(owner,dict(op='sellMaterial',bag=bi,slot=si,name=name,all=all,vendorGroup=group,vendorIndex=index))
    money=lambda:count('Copper Coins')+100*count('Silver Coins')+10000*count('Gold Coins')
    beforeMoney=money()
    before=count('Angled Timber');status,res,_=sell('Angled Timber',group='invalid');assert status==409,res;assert count('Angled Timber')==before
    status,res,_=sell('Angled Timber',index=99999);assert status==409,res
    status,res,_=sell('Cover Tent');assert status==409,res;assert count('Cover Tent')==2
    status,res,body=sell('Angled Timber');assert status==200,res;assert count('Angled Timber')==before-1 and res.get('shopSlots'),res
    assert money()>beforeMoney
    paid=money();assert paid-beforeMoney==int(res['reason'].split(' for ')[1].split()[0])
    revision=res['revision'];status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==revision
    assert money()==paid,'Replay paid twice'
    for name in ('Angled Timber','Horizontal Timber','Vertical Timber'):
        status,res,_=sell(name,True);assert status==200,res;assert count(name)==0
    stock=unpack(res['shopSlots']);stockSlot=next(int(i)for i,v in stock.items()if v.get('name')=='Angled Timber')
    status,res,_=camp(owner,dict(op='buyMaterial',slot=stockSlot,name='Angled Timber',qty=1,vendorGroup='shopkeeper',vendorIndex=1));assert status==200,res;assert count('Angled Timber')==1
    status,stored=http('/v1/characters/1',token=owner['token'],method='GET');assert status==200
    saved=unpack(json.loads(stored['character']['save']));assert saved['bags']==owner['state']['bags']
    record=stored['character'];status,res=http('/v1/characters/1',{'revision':owner['revision'],'character':record},owner['token'],'PUT');assert status==200,res
    s.eval(r"local w=SG_SERVER.world;local p=require('game.player').new();local sk=require('game.skills').new();p.x,p.y=100,100;local hits=0;for _,kind in ipairs({'chicken','rat','goblin','nagalian'})do local e={kind=kind,x=110,y=100,hp=1000,maxHp=1000,stats={}};for i=1,20 do p.attackCooldown=0;p.stamina=p.maxStamina;local ok,why=w:attackEnemy(e,p,sk,{},SG_SERVER.sprites);assert(ok,why);if why=='hit'then hits=hits+1 end end;assert(e.hp<1000,'No landed '..kind..' hit')end;assert(hits>0);return 'PASS melee chicken/rat/goblin/nagalian hits'")
    print(s.eval(r"""
local R=require('game.rune_inventory');local P=require('game.profile');local Shop=require('game.shop');local I=require('game.inventory');local w=SG_SERVER.world;local inv=I.new();inv.bagSlots={{size=20,slots={}}};inv:add('Angled Timber',2);local p=require('game.player').new();p.x,p.y=w.shopkeeper.x,w.shopkeeper.y
local a={id=999,slot=1,owner='test',player=p,inv=inv,skills=require('game.skills').new(),fieldcraft={}};w.shopkeeper.shop=Shop.new();local merchant=w.shopkeeper.shop;require('Server.camp_rules').install({[999]=a},{test={world=w}},SG_SERVER);a.room='test'
local function body(cmd)return{id=999,slot=1,owner='test',saved=P.pack({bags=a.inv.bagSlots,bank={},skills=a.skills.data}),command=cmd}end
local cmd={op='sellMaterial',bag=1,slot=1,name='Angled Timber',vendorGroup='shopkeeper',vendorIndex=1,all=true};local b=body(cmd);assert(SG_CAMP('camp_prepare',b).ok);local old=merchant.slots;local result=SG_CAMP('camp_command',b);assert(result.ok,result.reason);assert(a.inv:countItem('Angled Timber')==0 and merchant.slots~=old);assert(SG_CAMP('camp_rollback',b).ok);assert(a.inv:countItem('Angled Timber')==2 and merchant.slots==old and a.inv:moneyCopper()==0,'Sale rollback restores items/coins/stock')
p.x=p.x+1000;local bad=SG_CAMP('camp_command',body(cmd));assert(not bad.ok and a.inv:countItem('Angled Timber')==2,'Distant merchant rejected');p.x=p.x-1000
for _,name in ipairs({'Angled Timber','Horizontal Timber','Vertical Timber','Stump Pole','Bush Leaves'})do assert(Shop.new():acceptsSale(name)and Shop.trader():acceptsSale(name),name)end
for _,name in ipairs({'Cover Tent','Lean-to','Leather Drape Tent'})do assert(not Shop.new():acceptsSale(name),name)end
return 'PASS sale rollback, distant merchant rejection, all five building materials and protected tents'
"""))
    print('PASS melee chicken/rat/goblin/nagalian; authenticated building-material Sell, Sell All and buyback, invalid merchant/tent rejection, replay, durable inventory and ordinary save')
finally:
    service.shutdown();service.server_close()
