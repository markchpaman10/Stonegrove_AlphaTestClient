"""Persistent account storage, coherent SQLite migration, and one-server-per-store lock."""
import os, secrets, sqlite3
from contextlib import closing
from datetime import datetime
from pathlib import Path

def default_data_dir():
    base=os.environ.get('LOCALAPPDATA') or os.environ.get('XDG_DATA_HOME')
    return (Path(base) if base else Path.home()/'.local'/'share')/'Stonegrove'/'AccountServer'

def info(path):
    path=Path(path).resolve()
    with closing(sqlite3.connect(path.as_uri()+'?mode=ro',uri=True)) as c:
        if c.execute('PRAGMA quick_check').fetchone()[0]!='ok': raise ValueError('Database integrity check failed')
        users=c.execute('SELECT count(*) FROM users').fetchone()[0]
        admins=c.execute("SELECT count(*) FROM users WHERE role='admin'").fetchone()[0]
        characters=c.execute('SELECT count(*) FROM characters').fetchone()[0]
        # Check expected credential/save columns without displaying their contents.
        c.execute('SELECT id,name,salt,hash,role FROM users LIMIT 0')
        c.execute('SELECT token,user,expires FROM sessions LIMIT 0')
        c.execute('SELECT user,slot,revision,data FROM characters LIMIT 0')
        return {'path':path,'accounts':users,'admins':admins,'characters':characters}

def candidates(script_dir,home=None):
    home=Path(home) if home else Path.home();script_dir=Path(script_dir).resolve()
    paths=[script_dir/'server_data'/'accounts.sqlite3']
    roots=[home/'Desktop',home/'Downloads',home/'Documents']
    roots.extend(list(script_dir.parents)[:3])
    for root in set(roots):
        if not root.is_dir(): continue
        for pattern in ('*Stonegrove*/Server/server_data/accounts.sqlite3','*/*Stonegrove*/Server/server_data/accounts.sqlite3','*/*/*Stonegrove*/Server/server_data/accounts.sqlite3'):
            try: paths.extend(root.glob(pattern))
            except OSError: pass
    found={}
    for path in paths:
        try:
            record=info(path)
            if record['accounts']>0: found[str(record['path']).casefold()]=record
        except (OSError,sqlite3.Error,ValueError): pass
    return sorted(found.values(),key=lambda d:str(d['path']))

def snapshot(source,destination):
    source=Path(source).resolve();destination=Path(destination).resolve()
    if source==destination: return
    destination.parent.mkdir(parents=True,exist_ok=True)
    temporary=destination.with_name(destination.name+'.migration-'+secrets.token_hex(4)+'.tmp')
    try:
        with closing(sqlite3.connect(source.as_uri()+'?mode=ro',uri=True)) as src:
            with closing(sqlite3.connect(temporary)) as dst: src.backup(dst)
        info(temporary);os.replace(temporary,destination)
    finally:
        temporary.unlink(missing_ok=True)

def recover(source,target,replace=False):
    source=Path(source).resolve();target=Path(target).resolve();record=info(source)
    if record['accounts']==0: raise ValueError('The selected database contains no accounts')
    if source==target: return None
    backup=None
    if target.exists():
        existing=info(target)
        if existing['accounts'] and not replace: raise ValueError('The permanent store already contains accounts. Use Recover_Account_Data.bat to preserve a backup before switching databases.')
        if existing['accounts']:
            stamp=datetime.now().strftime('%Y%m%d-%H%M%S')+'-'+secrets.token_hex(2)
            backup=target.with_name('accounts.before-recovery-'+stamp+'.sqlite3');snapshot(target,backup)
    snapshot(source,target);return backup

def prepare(target,script_dir,interactive=False,legacy=None):
    target=Path(target)
    if target.exists() and info(target)['accounts']>0: return None
    if legacy:
        recover(legacy,target);return Path(legacy).resolve()
    choices=[d for d in candidates(script_dir) if d['path']!=target.resolve()]
    if not choices: return None
    if len(choices)==1: chosen=choices[0]
    else:
        print('Multiple existing account databases found. None will be overwritten:')
        for i,d in enumerate(choices,1): print(f"  {i}: {d['path']} ({d['accounts']} accounts, {d['characters']} characters)")
        if not interactive: raise ValueError('Run with --setup to choose a database, or provide --legacy-db PATH')
        answer=input('Choose the database to migrate (number); N explicitly starts new data: ').strip()
        if answer.lower()=='n': return None
        if not answer.isdigit() or not 1<=int(answer)<=len(choices): raise ValueError('No database chosen; existing data was left untouched')
        chosen=choices[int(answer)-1]
    recover(chosen['path'],target);return chosen['path']

class StoreLock:
    def __init__(self,folder): self.folder=Path(folder);self.file=None
    def __enter__(self):
        self.folder.mkdir(parents=True,exist_ok=True);self.file=open(self.folder/'server.lock','a+b')
        self.file.seek(0,2)
        if self.file.tell()==0: self.file.write(b'0');self.file.flush()
        self.file.seek(0)
        try:
            if os.name=='nt':
                import msvcrt;msvcrt.locking(self.file.fileno(),msvcrt.LK_NBLCK,1)
            else:
                import fcntl;fcntl.flock(self.file,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except OSError:
            self.file.close();self.file=None;raise ValueError('Another account server is already using this data directory. Stop that server first.')
        return self
    def __exit__(self,*args):
        if self.file:
            if os.name=='nt':
                import msvcrt;self.file.seek(0);msvcrt.locking(self.file.fileno(),msvcrt.LK_UNLCK,1)
            else:
                import fcntl;fcntl.flock(self.file,fcntl.LOCK_UN)
            self.file.close()
