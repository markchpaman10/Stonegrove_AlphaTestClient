"""Dedicated game simulation using the same Lua rules as the client."""
from simulation_lock import SimulationLock
from world_source import decode_world, GitHubWorld
import ctypes
import json
import os
import threading
import time
import zlib
import base64
from pathlib import Path


class EncodedResponse:
    """Already encoded by Lua; HTTP can forward it without rebuilding every row."""
    def __init__(self,body,totals):self.body=body.encode('utf-8');self.totals=totals
    def get(self,key,default=None):return self.totals if key=='skillTotals'else default

class Simulation:
    def __init__(self, root, world=None, data_dir=None):
        if not isinstance(world, GitHubWorld):
            raise ValueError('Simulation requires a fresh GitHub world download; local paths, cached files and bundled worlds are disabled')
        document = decode_world(world.raw)
        self.world_source = world
        self.root = Path(root).resolve()
        # Use the bundled LOVE Lua 5.1 runtime on Windows and the Render-built
        # LuaJIT 2.1 shared library on Linux. LuaJIT is Lua 5.1 API compatible.
        if os.name == 'nt':
            candidates = [
                self.root/'Server/Runtime/lua51.dll',
                Path(os.environ.get('PROGRAMFILES', 'C:/Program Files'))/'LOVE/lua51.dll',
            ]
            missing = 'Missing Server/Runtime/lua51.dll. Extract the complete developer build.'
        else:
            candidates = [
                self.root/'Server/Runtime/libluajit-5.1.so.2',
                self.root/'Server/Runtime/libluajit-5.1.so',
                Path('/usr/local/lib/libluajit-5.1.so.2'),
                Path('/usr/lib/x86_64-linux-gnu/libluajit-5.1.so.2'),
            ]
            missing = ('Missing Linux Lua 5.1 runtime. On Render use build command: '
                       'sh Server/build_render.sh')
        dll = next((p for p in candidates if p.is_file()), None)
        if dll is None:
            raise RuntimeError(missing)
        self.lib = ctypes.CDLL(str(dll))
        l = self.lib
        l.luaL_newstate.restype = ctypes.c_void_p
        l.luaL_openlibs.argtypes = [ctypes.c_void_p]
        l.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
        l.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        l.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
        l.lua_tolstring.restype = ctypes.c_void_p
        l.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
        l.lua_close.argtypes = [ctypes.c_void_p]
        self.state = l.luaL_newstate()
        l.luaL_openlibs(self.state)
        self.lock = SimulationLock()
        root_literal = json.dumps(self.root.as_posix())
        raw = json.dumps(document, ensure_ascii=True, separators=(',', ':'))
        package = 'SG_PACKAGE_RAW='+self.quote(raw)+';'
        try:
            self.eval('SG_SERVER_GENERATION='+str(time.time_ns()%1000000000)+';SG_ROOT='+root_literal+';package.path=SG_ROOT.."/?.lua;"..package.path;'+package+'dofile(SG_ROOT.."/Server/headless.lua");dofile(SG_ROOT.."/Server/shared_world.lua");return "ready"')
        except Exception:
            self.lib.lua_close(self.state)
            self.state = None
            raise
        self.started = time.monotonic()
        self.save_path = Path(data_dir)/'shared_world.json' if data_dir else None
        if self.save_path and self.save_path.is_file():
            try:
                from world_state import migrate
                self.call('restore', migrate(json.loads(self.save_path.read_text(encoding='utf-8'))))
            except Exception:
                self.lib.lua_close(self.state)
                self.state = None
                raise
        self.last_checkpoint = time.monotonic()
        self.stopped = threading.Event()
        self.error = None
        self.thread = threading.Thread(target=self.run, name='Stonegrove world simulation', daemon=True)
        self.thread.start()

    def __del__(self):
        # Release a Lua state if initialization failed before its thread started.
        if getattr(self, 'state', None) and not hasattr(self, 'thread'):
            self.lib.lua_close(self.state)
            self.state = None

    @staticmethod
    def quote(raw):
        return '"'+raw.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r')+'"'

    def run(self):
        previous = time.monotonic()
        deadline = previous + .05
        while not self.stopped.wait(max(0, deadline-time.monotonic())):
            now = time.monotonic()
            deadline += .05
            if deadline < now:deadline = now + .05
            try:
                self.call('tick', {'time': now-self.started, 'dt': min(.1, now-previous)})
                if self.save_path and now-self.last_checkpoint>=30:
                    self.checkpoint()
                    self.last_checkpoint = now
            except Exception as e:
                self.error = str(e)
                self.stopped.set()
            previous = now

    def eval(self, code):
        with self.lock:
            data = code.encode('utf-8')
            l = self.lib
            rc = l.luaL_loadbuffer(self.state, data, len(data), b'server')
            if not rc:
                rc = l.lua_pcall(self.state, 0, 1, 0)
            size = ctypes.c_size_t()
            ptr = l.lua_tolstring(self.state, -1, ctypes.byref(size))
            result = ctypes.string_at(ptr, size.value).decode('utf-8', errors='replace') if ptr else ''
            l.lua_settop(self.state, 0)
            if rc:
                raise RuntimeError(result)
            return result

    def call(self, method, data):
        # JSON is passed as a quoted data string, never as executable user Lua.
        raw = json.dumps(data, ensure_ascii=True, allow_nan=False, separators=(',', ':'))
        literal = self.quote(raw)
        with self.lock.priority(method=='tick'):
            encoded=self.eval('return SG_CALL('+json.dumps(method)+','+literal+')')
            result=EncodedResponse(encoded,json.loads(self.eval('return SG_EXCHANGE_TOTALS')))if method=='exchange_encoded'else json.loads(encoded)
            if self.save_path and method in ('tick','exchange','exchange_encoded','delete_character'):
                signature=json.dumps(self.call('grave_version',{}),sort_keys=True)
                if signature!=getattr(self,'grave_signature',None):
                    self.checkpoint();self.grave_signature=signature
            if self.save_path and method=='camp_commit' and str(data.get('op','')).startswith('container'):
                self.checkpoint()
            return result

    def close(self):
        self.stopped.set()
        if threading.current_thread() is not self.thread:
            self.thread.join(timeout=5)
        with self.lock:
            if self.state:
                if self.save_path:
                    self.checkpoint()
                self.lib.lua_close(self.state)
                self.state = None

    def checkpoint(self):
        data = self.call('export', {})
        self.save_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.save_path.with_suffix('.pending')
        temporary.write_text(json.dumps(data, ensure_ascii=True, separators=(',', ':')), encoding='utf-8')
        os.replace(temporary, self.save_path)
