"""Durable camp ledger. Existing account tables and serialized saves are retained.

No submitted item counts/XP are used by camp operations. They start from the
stored character and execute the shared Lua rules under the SQLite write lock.
Active camps are journaled before acknowledgement; interrupted sessions recover
storage without returning the Tent. All recovery is independent of a client.
"""
import json
import sqlite3
import time
import threading
from contextlib import closing


def unpack(v):
    if not isinstance(v, dict): return v
    if v.get('nilValue'): return None
    if 'array' in v: return {i+1: unpack(x) for i, x in enumerate(v['array'])}
    if 'entries' not in v: raise ValueError('Invalid packed character')
    return {e['key']: unpack(e['value']) for e in v['entries']}


def pack(v):
    if isinstance(v, dict): return {'entries': [{'key': k, 'value': pack(x)} for k, x in v.items() if x is not None]}
    if isinstance(v, list): return {'array': [pack(x) for x in v]}
    return v


def numeric(v):
    if isinstance(v,dict):return {(int(k)if isinstance(k,str)and k.isdigit()else k):numeric(x)for k,x in v.items()}
    if isinstance(v,list):return [numeric(x)for x in v]
    return v

class Camps:
    grace = 45
    def __init__(self, service):
        self.observed={};self.service=service;self.lock=threading.RLock();self.stop=threading.Event()
        with closing(sqlite3.connect(service.db)) as c:
            c.execute('CREATE TABLE IF NOT EXISTS fieldcraft(user INTEGER,slot INTEGER,data TEXT,active TEXT,seen REAL,owner TEXT,PRIMARY KEY(user,slot))')
            c.execute('CREATE TABLE IF NOT EXISTS camp_requests(user INTEGER,slot INTEGER,key TEXT,response TEXT,PRIMARY KEY(user,slot,key))')
            # Server restart is a disconnect; already-consumed Tents remain lost.
            for user,slot in c.execute("SELECT user,slot FROM fieldcraft").fetchall(): self.recover(c,user,slot)
            c.commit()
        self.thread=threading.Thread(target=self.run,name='Camp session cleanup',daemon=True);self.thread.start()

    def protect(self,c,user,slot,data):
        row=c.execute('SELECT data FROM fieldcraft WHERE user=? AND slot=?',(user,slot)).fetchone()
        from graves import protect
        data=protect(self.service,user,slot,data)
        saved=unpack(json.loads(data['save']))
        ledger=numeric(json.loads(row[0]))if row else {'config':{'layout':{},'built':{},'recovery':{},'regions':{}},'xp':{'Fieldcraft':0,'Survival':0,'Foraging':0}}
        saved['fieldcraft']=ledger['config']
        for name,xp in ledger['xp'].items():saved.setdefault('skills',{})[name]={'xp':xp}
        previous=c.execute('SELECT data FROM characters WHERE user=? AND slot=?',(user,slot)).fetchone()
        old=unpack(json.loads(protect(self.service,user,slot,json.loads(previous[0]))['save']))if previous else {}
        import bag_rules
        bag_rules.migrate(saved)
        bag_rules.validate(saved)
        protected={'Angled Timber','Horizontal Timber','Vertical Timber','Bush Leaves','Stump Pole','Cover Tent','Lean-to','Leather Drape Tent','Shrimp Pot','Crab Pot','Lobster Pot'}
        def counts(state):
            totals={n:0 for n in protected}
            slots=list(state.get('bank',{}).values())
            for bag in state.get('bags',{}).values():slots.extend(bag.get('slots',{}).values())
            for obj in slots:
                if obj and obj.get('name')in totals:totals[obj['name']]+=obj.get('qty',1)
            pots=sorted(json.dumps({k:v for k,v in obj.items()if k not in ('qty','sockets')},sort_keys=True)for obj in slots if obj and obj.get('name')in ('Shrimp Pot','Crab Pot','Lobster Pot'))
            return totals,pots
        before,after=counts(old),counts(saved)
        if before!=after:raise ValueError('Camp items must be crafted and transferred by the server')
        return dict(data,save=json.dumps(pack(saved),separators=(',',':')))

    def recover(self,c,user,slot):
        row=c.execute('SELECT data,active FROM fieldcraft WHERE user=? AND slot=?',(user,slot)).fetchone()
        if not row: return
        if not row[1] and not numeric(json.loads(row[0]))['config'].get('pots'): return
        ledger=numeric(json.loads(row[0]));camp=unpack(json.loads(row[1])) if row[1] else {};config=ledger['config'];recovery=config.setdefault('recovery',{})
        for obj in camp.get('storage',{}).values(): recovery[max([0]+[int(x)for x in recovery])+1]=obj
        config.pop('active',None);config.pop('activeTent',None);config.pop('pots',None)
        c.execute('UPDATE fieldcraft SET data=?,active=? WHERE user=? AND slot=?',(json.dumps(ledger),'',user,slot))
        char=c.execute('SELECT revision,data FROM characters WHERE user=? AND slot=?',(user,slot)).fetchone()
        if char:
            data=json.loads(char[1]);saved=unpack(json.loads(data['save']));saved['fieldcraft']=config
            for name,xp in ledger['xp'].items(): saved.setdefault('skills',{})[name]={'xp':xp}
            data['save']=json.dumps(pack(saved),separators=(',',':'));c.execute('UPDATE characters SET data=?,revision=? WHERE user=? AND slot=?',(json.dumps(data),char[0]+1,user,slot))

    def leave(self,user,owner):
        with self.lock,closing(sqlite3.connect(self.service.db)) as c:
            c.execute('BEGIN IMMEDIATE')
            for slot, in c.execute('SELECT slot FROM fieldcraft WHERE user=? AND owner=?',(user,owner)).fetchall():
                if self.service.simulation: self.service.simulation.call('camp_cleanup',{'id':user,'slot':slot})
                self.recover(c,user,slot)
            c.commit()

    def baseline(self,user,slot):
        with self.lock:
            previous=self.observed.get((user,slot))
            if previous and time.monotonic()-previous[2]<5:return dict(previous[1])
        with closing(sqlite3.connect(self.service.db))as c:
            record=c.execute('SELECT data FROM fieldcraft WHERE user=? AND slot=?',(user,slot)).fetchone()
            if record:return json.loads(record[0])['xp']
            char=c.execute('SELECT data FROM characters WHERE user=? AND slot=?',(user,slot)).fetchone()
            if not char:return {}
            saved=unpack(json.loads(json.loads(char[0])['save']))
            return {'Fieldcraft':0,'Survival':0,'Foraging':0}

    def observe(self,user,slot,owner,totals):
        if set(totals)!={'Fieldcraft','Survival','Foraging'}:return
        key=(user,slot);now=time.monotonic()
        with self.lock:
            previous=self.observed.get(key)
            if previous and previous[0]==owner and previous[1]==totals and now-previous[2]<5:return
        with self.lock,closing(sqlite3.connect(self.service.db))as c:
            record=c.execute('SELECT data FROM fieldcraft WHERE user=? AND slot=?',(user,slot)).fetchone()
            ledger=numeric(json.loads(record[0]))if record else {'config':{'layout':{},'built':{},'recovery':{},'regions':{}},'xp':{}}
            ledger['xp']=totals
            if record:c.execute('UPDATE fieldcraft SET data=?,seen=?,owner=? WHERE user=? AND slot=?',(json.dumps(ledger),time.time(),owner,user,slot))
            else:c.execute('INSERT INTO fieldcraft VALUES(?,?,?,?,?,?)',(user,slot,json.dumps(ledger),'',time.time(),owner))
            c.commit()
            self.observed[key]=(owner,dict(totals),now)

    def heartbeat(self,user,slot,owner):
        with closing(sqlite3.connect(self.service.db)) as c:
            c.execute('UPDATE fieldcraft SET seen=? WHERE user=? AND slot=? AND owner=?',(time.time(),user,slot,owner));c.commit()

    def execute(self,user,slot,owner,body,admin_live=None):
        key=body.get('request');revision=body.get('revision')
        if not isinstance(body.get('command'),dict):raise ValueError('Invalid camp command')
        if not isinstance(key,str)or not 1<=len(key)<=100 or type(revision)is not int: raise ValueError('Invalid camp request')
        with self.lock,closing(sqlite3.connect(self.service.db)) as c:
            c.execute('BEGIN IMMEDIATE')
            previous=c.execute('SELECT response FROM camp_requests WHERE user=? AND slot=? AND key=?',(user,slot,owner+':'+key)).fetchone()
            if previous:
                response=json.loads(previous[0]);current=c.execute('SELECT revision FROM characters WHERE user=? AND slot=?',(user,slot)).fetchone()
                if not current or current[0]!=response.get('revision'):return 409,{'error':'This camp request already completed; character state has changed. Reload the server character.'}
                return 200,dict(response,_adminReplay=True)if admin_live is not None else response
            row=c.execute('SELECT revision,data FROM characters WHERE user=? AND slot=?',(user,slot)).fetchone()
            if not row: return 409,{'error':'Save your character before camping'}
            if revision!=row[0]: return 409,{'error':'Character changed; reload the server character before retrying','revision':row[0]}
            from graves import protect
            data=protect(self.service,user,slot,json.loads(row[1]));saved=unpack(json.loads(data['save']))
            if admin_live is not None:saved.update(unpack(admin_live))
            record=c.execute('SELECT data FROM fieldcraft WHERE user=? AND slot=?',(user,slot)).fetchone()
            if record:
                ledger=numeric(json.loads(record[0]));saved['fieldcraft']=ledger['config']
                for name,xp in ledger['xp'].items(): saved.setdefault('skills',{})[name]={'xp':xp}
            simulation=self.service.simulation
            if not simulation:return 409,{'error':'Connect to multiplayer before camping'}
            identity={'id':user,'slot':slot,'owner':owner,'op':(body.get('command')or{}).get('op')}
            mutating=identity['op']!='begin'
            with simulation.lock:
                if mutating:simulation.call('camp_prepare',identity)
                try:
                    result=simulation.call('camp_command',{'id':user,'slot':slot,'owner':owner,'command':body.get('command'),'saved':pack(saved)})
                    if not result.get('ok'):
                        if mutating:simulation.call('camp_rollback',identity)
                        return 409,{'error':result.get('reason','Camp action failed')}
                    if result.get('begin'): return 200,result
                    state=unpack(result['state'])
                    for name in ('bags','bank','bankSize','fieldcraft'): saved[name]=state[name]
                    saved['skills']=state['skills']
                    if 'hp'in state:saved.setdefault('player',{})['hp']=state['hp']
                    for field in ('bonfireBuffUntil','bonfireLastSource','maxHp'):
                        if field in state.get('status',{}):saved.setdefault('player',{})[field]=state['status'][field]
                    if 'potionBelt'in state:saved['potionBelt']=state['potionBelt']
                    if result.get('adminPlayer'):saved.setdefault('player',{}).update(unpack(result['adminPlayer']))
                    if result.get('destination'):saved['regionId']=result['destination']['region'];saved.pop('caveId',None)
                    data['save']=json.dumps(pack(saved),separators=(',',':'));rev=row[0]+1
                    ledger={'config':state['fieldcraft'],'xp':{n:state['skills'][n]['xp']for n in ('Fieldcraft','Survival','Foraging')}}
                    c.execute('INSERT OR REPLACE INTO fieldcraft VALUES(?,?,?,?,?,?)',(user,slot,json.dumps(ledger),json.dumps(result['camp'])if result.get('camp')else'',time.time(),owner))
                    c.execute('UPDATE characters SET data=?,revision=? WHERE user=? AND slot=?',(json.dumps(data),rev,user,slot))
                    result['revision']=rev
                    c.execute('INSERT INTO camp_requests VALUES(?,?,?,?)',(user,slot,owner+':'+key,json.dumps(result)))
                    c.execute('DELETE FROM camp_requests WHERE user=? AND slot=? AND rowid NOT IN(SELECT rowid FROM camp_requests WHERE user=? AND slot=? ORDER BY rowid DESC LIMIT 128)',(user,slot,user,slot))
                    c.commit()
                    if mutating:simulation.call('camp_commit',identity)
                    self.service.remember_character(user,slot,data,rev);return 200,result
                except Exception:
                    if mutating:simulation.call('camp_rollback',identity)
                    raise

    def execute_target(self,user,slot,owner,body):
        if not isinstance(body.get('request'),str)or not 1<=len(body['request'])<=100:return 409,{'error':'Invalid admin request'}
        command=body['command'];target=command.get('targetId');target_slot=command.get('targetSlot')
        if type(target)is not int or type(target_slot)is not int or target_slot not in(1,2,3):return 409,{'error':'Select a connected player'}
        if command.get('serverAdmin')is not True:return 403,{'error':'Administrator authorization required'}
        simulation=self.service.simulation
        if simulation is None:return 409,{'error':'Shared world is not running'}
        with self.lock,simulation.lock:
            info=simulation.call('admin_info',{'id':target,'slot':target_slot})
            if not info.get('ok'):return 409,{'error':info.get('reason','Player unavailable')}
            with closing(sqlite3.connect(self.service.db))as c:
                row=c.execute('SELECT revision FROM characters WHERE user=? AND slot=?',(target,target_slot)).fetchone()
            if not row:return 409,{'error':'Target character has no save'}
            request=dict(body,revision=row[0],request='admin:'+str(user)+':'+__import__('hashlib').sha256(body['request'].encode()).hexdigest())
            request['command']=dict(command);request['command'].pop('targetId',None);request['command'].pop('targetSlot',None)
            status,result=self.execute(target,target_slot,info['owner'],request,admin_live=info['personal'])
            if status!=200:return status,result
            state=unpack(result['state']);live=unpack(info['personal']);live.update(state);live['player'].update(unpack(result.get('adminPlayer',pack({}))))
            if not result.get('_adminReplay'):simulation.call('admin_sync',{'id':target,'slot':target_slot,'owner':info['owner'],'revision':result['revision'],'personal':pack(live),'destination':result.get('destination')})
            return 200,{'ok':True,'reason':'Target player: '+result.get('reason','Updated')}

    def run(self):
        while not self.stop.wait(5):
            try:
                with closing(sqlite3.connect(self.service.db)) as c:
                    rows=c.execute("SELECT user,owner FROM fieldcraft WHERE seen<?",(time.time()-self.grace,)).fetchall()
                for user,owner in rows:self.leave(user,owner)
            except Exception:
                import traceback;traceback.print_exc() # No body, credentials or locals.

    def close(self):self.stop.set();self.thread.join(6)
