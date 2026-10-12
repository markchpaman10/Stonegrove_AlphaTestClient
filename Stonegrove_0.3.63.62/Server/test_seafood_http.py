"""Authenticated two-account camp API integration tests; isolated QA database."""
from pathlib import Path
import json,sys,time,threading,sqlite3,urllib.request,urllib.error,hashlib
from contextlib import closing
from simulation import Simulation
from camps import Camps,pack,unpack
import server

root=Path(__file__).resolve().parent.parent
folder=root/'Server'/'seafood_http_test_data';folder.mkdir(exist_ok=True)
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
    status,res,_=camp(owner,{'op':'admin','action':'level','skill':'Cooking','amount':99});assert status==200,res
    for item,amount in [('Raw Lobster Tail',3),('Large Meat',2),('Lobster',3),('Copper Knife',1)]:
        status,res,_=camp(owner,{'op':'admin','action':'give','item':item,'amount':amount});assert status==200,res
    def count(name):return sum(it.get('qty',1)for bag in owner['state']['bags'].values()for it in bag['slots'].values()if it and it.get('name')==name)
    def locate(name):return next((bi,si)for bi,bag in owner['state']['bags'].items()for si,it in bag['slots'].items()if it and it.get('name')==name)
    def timed(command,duration=.65):
        status,res,_=camp(owner,dict(op='begin',next=command));assert status==200,res
        status,res,_=camp(owner,command);assert status==409,'Premature completion accepted'
        time.sleep(duration);status,res,body=camp(owner,command);assert status==200,res
        status,replay=http('/v1/camp',body,owner['token']);assert status==200 and replay['revision']==res['revision'],'Replay duplication'
        return res
    s.eval("local w=SG_SERVER.world;w.playerCamps=w.playerCamps or{};w.playerCamps[#w.playerCamps+1]={owner='qa',x="+str(owner['state']['player']['x'])+",y="+str(owner['state']['player']['y'])+",tent='Lean-to',structures={{id='cook',x="+str(owner['state']['player']['x'])+",y="+str(owner['state']['player']['y'])+"}}};return 'stove'")
    recipes=json.loads(s.eval("local out={};for i,r in ipairs(require('game.crafting').new():getRecipes('stove'))do if r.seafood then out[r.output]=i end end;return require('game.json').encode(out)"))
    for output in ('Cooked Lobster Tail','Surf and Turf'):
        before=count('Raw Lobster Tail');meat=count('Large Meat');timed(dict(op='craft',station='stove',index=recipes[output]));assert count('Raw Lobster Tail')==before-1
        assert count('Large Meat')==meat-(output=='Surf and Turf')
        assert any(it and (it['name'].startswith(output+' ')or it['name']=='Burnt '+output.replace('Cooked ','')) for bag in owner['state']['bags'].values()for it in bag['slots'].values())
    bi,si=locate('Lobster');before=count('Raw Lobster Tail')
    s.eval("SG_SEAFOOD_RANDOM=math.random;math.random=function(a,b)if a then return SG_SEAFOOD_RANDOM(a,b)end;return .01 end;return 'forced rare reward'")
    timed(dict(op='shellFillet',bag=bi,slot=si),2.05);s.eval("math.random=SG_SEAFOOD_RANDOM;return 'restored'")
    assert count('Lobster')==0 and count('Lobster Parts')==3 and count('Raw Lobster Tail')==before+3
    # Exercise authenticated belt healing with a server-stored food portion.
    with closing(sqlite3.connect(db))as c:
        uid=c.execute("SELECT id FROM users WHERE name='camp_owner'").fetchone()[0]
        revision,raw=c.execute('SELECT revision,data FROM characters WHERE user=? AND slot=1',(uid,)).fetchone();record=json.loads(raw);state=unpack(json.loads(record['save']));state['potionBelt']={1:'Surf and Turf A'};record['save']=json.dumps(pack(state));c.execute('UPDATE characters SET data=? WHERE user=? AND slot=1',(json.dumps(record),uid));c.commit()
    s.eval("for _,a in ipairs(SG_SERVER.world.onlineActors or{})do a.player.hp=1;a.player.maxHp=200 end;return 'hurt'")
    status,res,_=camp(owner,dict(op='beltFood',slot=1));assert status==200,res;state=unpack(res['state']);assert state['hp']==131 and state['potionBelt']=={}
    status,res,_=camp(owner,dict(op='beltFood',slot=1));assert status==409,'Food used twice'
    status,res=http('/v1/characters/1',None,owner['token'],'GET');assert status==200;stored=unpack(json.loads(res['character']['save']));assert stored['bags']==owner['state']['bags'] and stored['potionBelt']=={}
    print('PASS authenticated seafood cooking, exact ingredients, grades/burnt outcomes, timed bulk break, per-lobster tail rewards, replay, food-belt healing and durable inventory')
finally:
    service.shutdown();service.server_close();service.simulation.close();__import__('gc').collect();db.unlink();folder.rmdir()
