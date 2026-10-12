"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'bags_http_test_data';folder.mkdir(exist_ok=True)
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
    import bag_rules,copy
    legitimate=copy.deepcopy(owner['state']);legitimate['bagSchemaVersion']=2;bag_rules.validate(legitimate)
    forged=copy.deepcopy(legitimate);forged['bags'][1]['size']=128
    badrecord={'name':'camp_owner','race':'Human','save':json.dumps(pack(forged))}
    status,result=http('/v1/characters/1',{'revision':owner['revision'],'character':badrecord},owner['token'],'PUT');assert status==400,(status,result)
    forged=copy.deepcopy(legitimate);forged['skills']['Strength']={'xp':0,'level':99}
    for bag in forged['bags'].values():bag['size']=10
    badrecord['save']=json.dumps(pack(forged));status,result=http('/v1/characters/1',{'revision':owner['revision'],'character':badrecord},owner['token'],'PUT');assert status==400,(status,result)
    print('PASS authenticated server rejects forged bag capacity and locked fourth slot')
    def count(item):return sum(v.get('qty',1)for b in owner['state']['bags'].values()for v in b.get('slots',{}).values()if v and v.get('name')==item)
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
    bagrecipes=json.loads(s.eval("local out={};for station,list in pairs(require('game.crafting').new():allRecipes())do for i,r in ipairs(list)do if r.bagRecipe then out[r.output]={station=station,index=i,skill=r.skill,level=r.level,needs=r.needs}end end end;return require('game.json').encode(out)"))
    # Move the earlier QA fixture materials to the existing bank, preserving counts.
    bank=owner['state'].setdefault('bank',{})
    for bag in owner['state']['bags'].values():
        for slot,obj in list(bag['slots'].items()):
            if obj['name']not in ('Needle','Wizard Robes'):
                index=1
                while bank.get(index):index+=1
                bank[index]=obj;del bag['slots'][slot]
    owner['state']['bankSize']=max(25,max(bank,default=0));owner['state']['bagSchemaVersion']=2
    record={'name':'camp_owner','race':'Human','save':json.dumps(pack(owner['state']))}
    status,saved=http('/v1/characters/1',{'revision':owner['revision'],'character':record},owner['token'],'PUT');assert status==200,saved;owner['revision']=saved['revision']
    for item,r in bagrecipes.items():
        for name,amount in r['needs']:
            status,res,_=camp(owner,{'op':'admin','action':'give','item':name,'amount':amount});assert status==200,res
        status,res,_=camp(owner,{'op':'admin','action':'level','skill':r['skill'],'amount':r['level']-1});assert status==200,res
        cmd={'op':'craft','station':r['station'],'index':r['index']}
        status,res,_=camp(owner,{'op':'begin','next':cmd});assert status==200,res
        time.sleep(.65);status,res,_=camp(owner,cmd);assert status==409,res
        status,res,_=camp(owner,{'op':'admin','action':'level','skill':r['skill'],'amount':r['level']});assert status==200,res
        before={n[0]:count(n[0])for n in r['needs']};xp=owner['state']['skills'][r['skill']]['xp']
        status,res,_=camp(owner,{'op':'begin','next':cmd});assert status==200,res
        time.sleep(.65);status,res,body=camp(owner,cmd);assert status==200,res
        assert count(item)==1 and owner['state']['skills'][r['skill']]['xp']>xp,item
        for name,amount in r['needs']:assert count(name)==before[name]-amount,(item,name)
        status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==res['revision'],'Bag replay duplicate'
    print('PASS authenticated crafting of all six bags at10/20/30, lower-level rejection, exact materials, XP and replay protection')

    advanced=json.loads(s.eval("local out={};for _,r in ipairs(require('game.advanced_gear').recipes)do for i,v in ipairs(require('game.crafting').new():getRecipes(r.station))do if v.output==r.output then out[r.output]={station=r.station,index=i,needs=r.needs,skill=r.skill,xp=r.xp,level=r.level,tool=r.tool}end end end;return require('game.json').encode(out)"))
    for skill in ('Tailoring','Smithing','Leatherworking','Fletching','Woodworking'):
        status,res,_=camp(owner,{'op':'admin','action':'level','skill':skill,'amount':99});assert status==200,res
    for item,amount in [('Iron Tongs',1),('Iron Hammer',1)]:
        status,res,_=camp(owner,{'op':'admin','action':'give','item':item,'amount':amount});assert status==200,res
    x=owner['state']['player']['x'];y=owner['state']['player']['y']
    def advanced_cast(item,expected=200):
        owner['seq']+=1
        heartbeat=dict(owner['body'],initial=False,seq=owner['seq'],personal=pack(owner['state']))
        status,presence=http('/v1/multiplayer',heartbeat,owner['token']);assert status==200,presence
        r=advanced[item]
        if r.get('tool')and count(r['tool'])==0:
            status,res,_=camp(owner,{'op':'admin','action':'give','item':r['tool'],'amount':1});assert status==200,res
        for name,amount in r['needs']:
            missing=amount-count(name)
            if missing>0:
                status,res,_=camp(owner,{'op':'admin','action':'give','item':name,'amount':missing});assert status==200,res
        cmd={'op':'craft','station':r['station'],'index':r['index']}
        before={n[0]:count(n[0])for n in r['needs']};xp=owner['state']['skills'][r['skill']]['xp'];output=count(item)
        status,res,_=camp(owner,{'op':'begin','next':cmd});assert status==200,res
        status,res,_=camp(owner,cmd);assert status==409,'Early cast accepted'
        time.sleep(.65);status,res,body=camp(owner,cmd);assert status==expected,res
        if status==200:
            assert count(item)==output+1,(item,count(item),output)
            for name,amount in r['needs']:assert count(name)==before[name]-amount,(item,name)
            assert owner['state']['skills'][r['skill']]['xp']>xp,'XP missing'
            status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==res['revision'],'Replay changed revision'
        else:
            assert all(count(n)==amount for n,amount in before.items())and owner['state']['skills'][r['skill']]['xp']==xp,'Rejected craft consumed resources'
    advanced_cast('Iron Weave Thread',409)
    s.eval("local w=SG_SERVER.world;for _,id in ipairs({'metalLoom','anvil','smelter'})do w.authoredObjects[#w.authoredObjects+1]={id=id,x="+str(x)+",y="+str(y)+"}end;return 'ok'")
    for item in advanced:advanced_cast(item)
    print('PASS authenticated local HTTP all advanced recipes: exact materials, correct skill XP, loom proximity rejection, timed casts and replay idempotence')

    status,record=http('/v1/characters/1',None,owner['token'],'GET');assert status==200
    persisted=unpack(json.loads(record['character']['save']));assert any(v and v['name']=='Wizard Robes'for b in persisted['bags'].values()for v in b.get('slots',{}).values()),'Crafted gear not durable'
    assert any(v and v['name']=='Wizard Robes'and v.get('qualityGrade')in 'ABCD'for b in persisted['bags'].values()for v in b.get('slots',{}).values()),'Crafted grade not durable'
    legacy=copy.deepcopy(guest['state']);legacy.pop('bagSchemaVersion',None);legacy['bags']={1:{'name':'Large Leather Bag A','size':26,'slots':{i:{'name':'Copper Axe','qty':1,'qualityGrade':'A'if i%2 else 'D'}for i in range(1,27)}}};legacy['bank']={}
    legacy_record={'name':'camp_guest','race':'Human','save':json.dumps(pack(legacy))}
    with closing(sqlite3.connect(db))as c:
        uid=c.execute("SELECT id FROM users WHERE name='camp_guest'").fetchone()[0]
        c.execute('UPDATE characters SET data=? WHERE user=? AND slot=1',(json.dumps(legacy_record),uid));c.commit()
    status,loaded=http('/v1/characters/1',None,guest['token'],'GET');assert status==200,loaded
    migrated=unpack(json.loads(loaded['character']['save']));bag_rules.validate(migrated)
    assert migrated['bags'][1]['qualityGrade']=='A'and migrated['bags'][1]['size']==19 and len(migrated['bank'])==7,'Legacy overflow migration'
    assert sum(len(b.get('slots',{}))for b in migrated['bags'].values())+len(migrated['bank'])==26,'Legacy item loss'
    status,stored=http('/v1/characters/1',{'revision':loaded['revision'],'character':loaded['character']},guest['token'],'PUT');assert status==200,stored
    status,again=http('/v1/characters/1',None,guest['token'],'GET');assert status==200 and unpack(json.loads(again['character']['save']))['bank']==migrated['bank'],'Migration must persist without duplicates'
    print('PASS authenticated legacy save migration, preserved grades, seven overflow items in bank and durable second login')
    print('PASS quality-rated authenticated local HTTP Tailoring: timed cast rejection, replay idempotence, dye/robe material consumption, server loom proximity, weaving/dyeing and durable inventory/XP; six new bag recipes and durable grades')
finally:
    service.shutdown();service.server_close();service.simulation.close();__import__('gc').collect();db.unlink();folder.rmdir()

