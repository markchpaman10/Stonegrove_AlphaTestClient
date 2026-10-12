"""Stonegrove account service. No third-party dependencies; never executes game saves."""
import os
import sys
from contextlib import ExitStack
from world_source import resolve_world, parse_link
import gzip
import argparse, base64, getpass, hashlib, hmac, json, re, secrets, sqlite3, ssl, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from storage import default_data_dir, prepare, recover, StoreLock
from presence import Presence
from simulation import Simulation, EncodedResponse
from camps import Camps, unpack
from contextlib import nullcontext, contextmanager
import threading
import traceback

def accepts_gzip(header):
    for entry in header.split(','):
        parts=entry.strip().lower().split(';')
        if parts[0]!='gzip':continue
        quality=1.0
        try:
            for part in parts[1:]:
                key,sep,value=part.strip().partition('=')
                if key=='q'and sep:quality=float(value)
        except ValueError:continue
        if 0<quality<=1:return True
    return False

@contextmanager
def connection(db,**kwargs):
    c=sqlite3.connect(db,**kwargs)
    try:
        with c:yield c
    finally:c.close()

def password_hash(password, salt):
    return hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), 600000).hex()

def initialize(db):
    with connection(db) as c:
        c.executescript('''CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY,name TEXT UNIQUE COLLATE NOCASE,salt TEXT,hash TEXT,role TEXT);
        CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY,user INTEGER,expires INTEGER);
        CREATE TABLE IF NOT EXISTS characters(user INTEGER,slot INTEGER CHECK(slot BETWEEN 1 AND 3),revision INTEGER,data TEXT,PRIMARY KEY(user,slot));
        CREATE TABLE IF NOT EXISTS deleted_characters(user INTEGER,slot INTEGER,revision INTEGER,PRIMARY KEY(user,slot));''')

def create_user(db, name, password, role='player'):
    if not re.fullmatch(r'[A-Za-z0-9_-]{3,24}', name): raise ValueError('Account name: 3–24 letters, numbers, underscores or hyphens.')
    if not 8 <= len(password) <= 128: raise ValueError('Password must contain 8–128 characters.')
    salt=secrets.token_hex(16)
    with connection(db) as c:
        c.execute('INSERT INTO users(name,salt,hash,role) VALUES(?,?,?,?)',(name,salt,password_hash(password,salt),role))

class Service(ThreadingHTTPServer):
    # Thirty clients can reconnect together; the default five pending sockets
    # causes TCP retries before a request ever reaches the simulation.
    request_queue_size=128
    def __init__(self,address,db):
        super().__init__(address,Handler);self.db=str(db);self.attempts={};self.presence=Presence();self.simulation=None;self.simulation_lock=threading.Lock();self.character_meta={};self.metadata_lock=threading.Lock();self.camps=None;self.account_locks={}

    def account_guard(self,user):
        with self.metadata_lock:
            return self.account_locks.setdefault(user,threading.RLock())

    def remember_character(self,user,slot,data,revision):
        saved=unpack(json.loads(data.get('save','{}')))
        religion=saved.get('skills',{}).get('Religion',{}).get('xp',0)if isinstance(saved,dict)else 0
        with self.metadata_lock:
            key=(user,slot);old=self.character_meta.get(key)
            if old is None or revision>=old[2]: self.character_meta[key]=(data.get('name','Adventurer'),data.get('race','Human'),revision,religion)
            while len(self.character_meta)>3072: self.character_meta.pop(next(iter(self.character_meta)))
            identity=self.character_meta[key]
        if self.camps:
            with self.camps.lock:self.camps.observed.pop(key,None)
        return identity

    def server_close(self):
        if self.camps: self.camps.close()
        if self.simulation: self.simulation.close()
        super().server_close()

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass # Credentials and save bodies never enter logs.
    def reply(self,status,value):
        body=value.body if isinstance(value,EncodedResponse)else json.dumps(value,separators=(',',':')).encode()
        compressed=False
        if isinstance(value,EncodedResponse)and len(body)>1024 and accepts_gzip(self.headers.get('Accept-Encoding','')):
            candidate=gzip.compress(body,compresslevel=1,mtime=0)
            if len(candidate)<len(body):body=candidate;compressed=True
        try:
            self.send_response(status)
            if compressed:self.send_header('Content-Encoding','gzip');self.send_header('Vary','Accept-Encoding')
            self.send_header('Content-Type','application/json');self.send_header('Cache-Control','no-store');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
            return True
        except (BrokenPipeError,ConnectionResetError,ConnectionAbortedError):
            # The client timed out/disconnected after the request was processed.
            # Do not turn a dead response socket into a second server error.
            self.close_connection=True
            return False
    def do_GET(self): self.run_request()
    def do_POST(self): self.run_request()
    def do_PUT(self): self.run_request()
    def do_DELETE(self): self.run_request()
    def run_request(self):
        try:
            length=int(self.headers.get('Content-Length','0'))
            if length<0 or length>16000000: return self.reply(413,{'error':'Request too large'})
            body=json.loads(self.rfile.read(length)) if length else {}
            if not isinstance(body,dict): raise ValueError('Expected an object')
            with connection(self.server.db,timeout=20) as c:
                path=self.path.rstrip('/');method=self.command
                if path in ('/v1/login','/v1/register') and method=='POST':
                    ip=self.client_address[0];now=time.time();attempts=[t for t in self.server.attempts.get(ip,[]) if now-t<60]
                    if len(attempts)>=12: return self.reply(429,{'error':'Wait a minute before trying again'})
                    attempts.append(now);self.server.attempts[ip]=attempts
                    name=body.get('name','');pw=body.get('password','')
                    if not isinstance(name,str) or not isinstance(pw,str) or len(name)>24 or len(pw)>128: raise ValueError('Invalid credentials')
                    if path.endswith('register'):
                        try: create_user(self.server.db,name,pw)
                        except sqlite3.IntegrityError: return self.reply(409,{'error':'Account name already exists'})
                    user=c.execute('SELECT id,name,salt,hash,role FROM users WHERE name=?',(name,)).fetchone()
                    if not user or not hmac.compare_digest(password_hash(pw,user[2]),user[3]): return self.reply(401,{'error':'Invalid account name or password'})
                    token=secrets.token_urlsafe(32);c.execute('DELETE FROM sessions WHERE expires<?',(int(now),));c.execute('INSERT INTO sessions VALUES(?,?,?)',(hashlib.sha256(token.encode()).hexdigest(),user[0],int(now)+86400))
                    c.commit();return self.reply(200,{'token':token,'id':user[0],'name':user[1],'role':user[4]})
                token=self.headers.get('Authorization','').removeprefix('Bearer ')
                session_key=hashlib.sha256(token.encode()).hexdigest()
                user=c.execute('SELECT u.id,u.name,u.role FROM users u JOIN sessions s ON u.id=s.user WHERE s.token=? AND s.expires>?',(hashlib.sha256(token.encode()).hexdigest(),int(time.time()))).fetchone()
                if not user: return self.reply(401,{'error':'Sign in again'})
                with self.server.account_guard(user[0]):
                    if path=='/v1/me' and method=='GET': return self.reply(200,{'id':user[0],'name':user[1],'role':user[2]})
                    if path=='/v1/camp/ping' and method=='POST':
                        slot=body.get('slot')
                        if type(slot)is not int or slot not in(1,2,3):raise ValueError('Invalid character slot')
                        if self.server.camps:self.server.camps.heartbeat(user[0],slot,session_key)
                        if self.server.simulation:self.server.simulation.call('camp_ping',{'id':user[0],'slot':slot,'owner':session_key})
                        return self.reply(200,{'ok':True})
                    if path=='/v1/camp' and method=='POST':
                        slot=body.get('slot')
                        if type(slot)is not int or slot not in(1,2,3):raise ValueError('Invalid character slot')
                        if body.get('command',{}).get('op')=='admin':
                            if user[2]!='admin':return self.reply(403,{'error':'Administrator authorization required'})
                            body=dict(body,command=dict(body['command'],serverAdmin=True))
                        with self.server.simulation_lock:
                            if self.server.camps is None:self.server.camps=Camps(self.server)
                        if body.get('command',{}).get('op')=='admin'and body['command'].get('targetId')is not None:status,result=self.server.camps.execute_target(user[0],slot,session_key,body)
                        else:status,result=self.server.camps.execute(user[0],slot,session_key,body)
                        return self.reply(status,result)
                    if path=='/v1/multiplayer' and method=='POST':
                        slot=body.get('slot');seq=body.get('seq')
                        if type(slot) is not int or slot not in (1,2,3) or type(seq) is not int or not 1<=seq<=2147483647: raise ValueError('Invalid multiplayer request')
                        with self.server.metadata_lock: identity=self.server.character_meta.get((user[0],slot))
                        if identity is None:
                            row=c.execute('SELECT revision,data FROM characters WHERE user=? AND slot=?',(user[0],slot)).fetchone()
                            if not row: return self.reply(409,{'error':'Save your character before joining the shared world'})
                            identity=self.server.remember_character(user[0],slot,json.loads(row[1]),row[0])
                        with self.server.simulation_lock:
                            if self.server.simulation is None: self.server.simulation=Simulation(Path(__file__).parent.parent,world=getattr(self.server,'world_source',None),data_dir=Path(self.server.db).parent)
                        simulation=self.server.simulation
                        if simulation.error: return self.reply(503,{'error':'World simulation stopped: '+simulation.error})
                        baseline=self.server.camps.baseline(user[0],slot)if self.server.camps else {}
                        buff_baseline={}
                        if body.get('initial'):
                            buff_row=c.execute('SELECT data FROM characters WHERE user=? AND slot=?',(user[0],slot)).fetchone()
                            if buff_row:
                                try:buff_baseline=unpack(json.loads(json.loads(buff_row[0]).get('save','{}'))).get('player',{})
                                except (ValueError,TypeError,AttributeError):pass
                        religion_baseline=identity[3]
                        body=dict(body,id=user[0],owner=session_key,name=identity[0],race=identity[1],skillBaseline=baseline,buffBaseline=buff_baseline,religionBaseline=religion_baseline)
                        try: result=simulation.call('exchange_encoded',body)
                        except RuntimeError as e: return self.reply(409,{'error':str(e).split('stack traceback:')[0][-500:]})
                        if self.server.camps:self.server.camps.observe(user[0],slot,session_key,result.get('skillTotals',{}))
                        return self.reply(200,result)
                    if path=='/v1/presence/leave' and method=='POST':
                        if self.server.camps:self.server.camps.leave(user[0],session_key)
                        self.server.presence.leave(user[0],session_key)
                        if self.server.simulation: self.server.simulation.call('leave',{'id':user[0],'owner':session_key})
                        return self.reply(200,{'ok':True})
                    if path=='/v1/presence' and method=='POST':
                        slot=body.get('slot')
                        if type(slot) is not int or slot not in (1,2,3): raise ValueError('Invalid slot')
                        name=self.server.presence.character_name(user[0],slot)
                        if name is None:
                            row=c.execute('SELECT revision,data FROM characters WHERE user=? AND slot=?',(user[0],slot)).fetchone()
                            if not row: return self.reply(409,{'error':'Save character before publishing presence'})
                            name=self.server.presence.remember_name(user[0],slot,json.loads(row[1]).get('name','Adventurer'),revision=row[0])
                        try: players=self.server.presence.heartbeat(user[0],session_key,name,body)
                        except OverflowError: return self.reply(503,{'error':'Map presence temporarily full'})
                        return self.reply(200,{'players':players,'ttl':self.server.presence.ttl})
                    if path=='/v1/logout' and method=='POST':
                        if self.server.simulation: self.server.simulation.call('leave',{'id':user[0],'owner':session_key})
                        if self.server.camps:self.server.camps.leave(user[0],session_key)
                        self.server.presence.leave(user[0],session_key)
                        c.execute('DELETE FROM sessions WHERE token=?',(hashlib.sha256(token.encode()).hexdigest(),));c.commit();return self.reply(200,{'ok':True})
                    if path=='/v1/characters' and method=='GET':
                        rows={s:(r,json.loads(d)) for s,r,d in c.execute('SELECT slot,revision,data FROM characters WHERE user=?',(user[0],))}
                        deleted=dict(c.execute('SELECT slot,revision FROM deleted_characters WHERE user=?',(user[0],)))
                        return self.reply(200,{'slots':[{'slot':s,'revision':rows[s][0],'name':rows[s][1].get('name','Adventurer'),'race':rows[s][1].get('race','Human')} if s in rows else {'slot':s,'revision':deleted.get(s,0),'name':'','race':''} for s in range(1,4)]})
                    match=re.fullmatch(r'/v1/characters/([123])',path)
                    if match:
                        slot=int(match[1]);row=c.execute('SELECT revision,data FROM characters WHERE user=? AND slot=?',(user[0],slot)).fetchone()
                        if method=='GET':
                            data=json.loads(row[1]) if row else None
                            if data:
                                from graves import protect
                                data=protect(self.server,user[0],slot,data)
                            if data and self.server.camps:data=self.server.camps.protect(c,user[0],slot,data)
                            if data: self.server.presence.remember_name(user[0],slot,data.get('name','Adventurer'),revision=row[0])
                            deleted=c.execute('SELECT revision FROM deleted_characters WHERE user=? AND slot=?',(user[0],slot)).fetchone()
                            return self.reply(200,{'revision':row[0] if row else deleted[0] if deleted else 0,'character':data})
                        if method=='DELETE':
                            # Serialize camp cleanup and same-account save/join/delete requests.
                            with self.server.camps.lock if self.server.camps else nullcontext():
                                c.execute('BEGIN IMMEDIATE')
                                row=c.execute('SELECT revision,data FROM characters WHERE user=? AND slot=?',(user[0],slot)).fetchone()
                                if not row:return self.reply(404,{'error':'This character slot is already empty.'})
                                if type(body.get('revision'))is not int or body['revision']!=row[0]:return self.reply(409,{'error':'Character changed. Refresh the character list before deleting.','revision':row[0]})
                                if body.get('name')!=json.loads(row[1]).get('name'):return self.reply(409,{'error':'Character identity changed. Refresh before deleting.'})
                                with self.server.presence.lock:
                                    active=self.server.presence.players.get(user[0])
                                    if active and active.get('slot')==slot and self.server.presence.clock()-active['seen']<self.server.presence.ttl:return self.reply(409,{'error':'Return this character to the launcher on all computers before deleting.'})
                                if self.server.simulation:
                                    result=self.server.simulation.call('delete_character',{'id':user[0],'slot':slot})
                                    if not result.get('ok'):return self.reply(409,{'error':'Return this character to the launcher on all computers before deleting. Wait for its online session to end.'})
                                revision=row[0]+1
                                c.execute('DELETE FROM characters WHERE user=? AND slot=?',(user[0],slot))
                                c.execute('INSERT OR REPLACE INTO deleted_characters VALUES(?,?,?)',(user[0],slot,revision))
                                tables={t[0]for t in c.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                                for table in ('fieldcraft','camp_requests'):
                                    if table in tables:c.execute('DELETE FROM '+table+' WHERE user=? AND slot=?',(user[0],slot))
                                c.commit()
                                with self.server.metadata_lock:self.server.character_meta.pop((user[0],slot),None)
                                if self.server.camps:
                                    with self.server.camps.lock:self.server.camps.observed.pop((user[0],slot),None)
                                with self.server.presence.lock:self.server.presence.names.pop((user[0],slot),None)
                                return self.reply(200,{'ok':True,'slot':slot,'revision':revision})
                        if method=='PUT':
                            c.execute('BEGIN IMMEDIATE');row=c.execute('SELECT revision FROM characters WHERE user=? AND slot=?',(user[0],slot)).fetchone();deleted=c.execute('SELECT revision FROM deleted_characters WHERE user=? AND slot=?',(user[0],slot)).fetchone();rev=row[0] if row else deleted[0] if deleted else 0
                            if type(body.get('revision')) is not int or body['revision']!=rev: return self.reply(409,{'error':'Character changed on another computer. Your local backup was kept.','revision':rev})
                            data=body.get('character')
                            if not isinstance(data,dict) or not isinstance(data.get('save'),str) or len(data['save'])>12000000: raise ValueError('Invalid character')
                            if data.get('race') not in ('Human','Elf','Dwarf') or not isinstance(data.get('name'),str) or not 1<=len(data['name'])<=80: raise ValueError('Invalid character identity')
                            from graves import protect
                            data=protect(self.server,user[0],slot,data)
                            if self.server.camps:data=self.server.camps.protect(c,user[0],slot,data)
                            c.execute('INSERT OR REPLACE INTO characters VALUES(?,?,?,?)',(user[0],slot,rev+1,json.dumps(data)));c.commit();self.server.presence.remember_name(user[0],slot,data['name'],revision=rev+1);self.server.remember_character(user[0],slot,data,rev+1);return self.reply(200,{'revision':rev+1})
                    return self.reply(404,{'error':'Unknown endpoint'})
        except (BrokenPipeError,ConnectionResetError,ConnectionAbortedError):
            self.close_connection=True
        except (ValueError,TypeError,json.JSONDecodeError): self.reply(400,{'error':'Invalid request'})
        except Exception as exc:
            # Keep credentials and request/save bodies out of logs. A traceback without
            # frame locals identifies code/runtime failures without dumping user state.
            print(f'Unhandled {self.command} {self.path} server error: {type(exc).__name__}: {exc}', flush=True)
            traceback.print_exc()
            self.reply(500,{'error':'Server error; check server logs'})

def main():
    p=argparse.ArgumentParser();p.add_argument('--data',default=str(default_data_dir()));p.add_argument('--host',default='127.0.0.1');p.add_argument('--port',type=int,default=8443);p.add_argument('--setup',action='store_true');p.add_argument('--world',help='Legacy alias for a GitHub world URL; local paths are rejected');p.add_argument('--world-link', default=None, help='Required GitHub world URL; downloaded afresh at every startup and remembered in the data directory');p.add_argument('--cert');p.add_argument('--key');p.add_argument('--legacy-db',help='Migrate an existing database when the permanent store is empty');p.add_argument('--recover',action='store_true',help='Choose an older database, backing up the current permanent store');p.add_argument('--recover-db',help='Same recovery operation with an explicit database path');a=p.parse_args()
    if a.world:
        from world_source import github_url
        github_url(parse_link(a.world))
        if a.world_link and github_url(a.world_link) != github_url(a.world):
            raise ValueError('Use one GitHub world link; --world and --world-link disagree')
        a.world_link = a.world
    a.world_link = a.world_link or os.environ.get('WORLD_LINK')
    # Hosted services supply PORT; local CLI defaults and overrides remain unchanged.
    if 'PORT' in os.environ:
        a.host = '0.0.0.0'
        a.port = int(os.environ['PORT'])
    folder=Path(a.data).expanduser().resolve();db=folder/'accounts.sqlite3'
    # Bind first: do not ask for new credentials when an old server still occupies this port.
    try: server=Service((a.host,a.port),db);server.world_source=None
    except OSError as e: raise ValueError(f'Cannot start account server on {a.host}:{a.port}. Stop the already-running server or choose another port. {e}')
    try:
        with StoreLock(folder), ExitStack() as shutdown:
            print('Permanent account database:',db,flush=True)
            if a.recover or a.recover_db:
                source=a.recover_db or input('Paste the older accounts.sqlite3 path (current data is backed up first): ').strip().strip('"')
                backup=recover(source,db,replace=True)
                if backup: print('Previous permanent database preserved at:',backup,flush=True)
                print('Recovered account data from:',Path(source).resolve(),flush=True)
            else:
                migrated=prepare(db,Path(__file__).parent,interactive=a.setup,legacy=a.legacy_db)
                if migrated: print('Migrated existing accounts and characters from:',migrated,flush=True)
            initialize(db)
            server.world_source=resolve_world(Path(__file__).parent.parent,folder,world=a.world,link=a.world_link,interactive=sys.stdin.isatty() and 'PORT' not in os.environ)
            server.simulation=Simulation(Path(__file__).parent.parent,world=server.world_source,data_dir=folder)
            shutdown.callback(server.simulation.close)
            print('GitHub world simulation loaded successfully; ready for players.',flush=True)
            server.camps=Camps(server)
            with connection(db) as c: admins=c.execute("SELECT name FROM users WHERE role='admin'").fetchall()
            if a.setup and not admins:
                create_user(db,input('Admin account name: ').strip(),getpass.getpass('Admin password (8+ characters): '),'admin')
                with connection(db) as c: admins=c.execute("SELECT name FROM users WHERE role='admin'").fetchall()
            if admins: print('Existing admin account(s):',', '.join(row[0] for row in admins),flush=True)
            if a.cert and a.key:
                context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.minimum_version=ssl.TLSVersion.TLSv1_2;context.load_cert_chain(a.cert,a.key);server.socket=context.wrap_socket(server.socket,server_side=True)
            print('Stonegrove account server listening on',server.server_address[0],server.server_port,flush=True)
            server.serve_forever()
    finally:
        server.server_close()
if __name__=='__main__':
    try: main()
    except KeyboardInterrupt: print('Server stopped. Account data remains saved.')
    except (ValueError,OSError,RuntimeError,sqlite3.Error) as e: print('Account server could not start:',e,flush=True);raise SystemExit(1)
