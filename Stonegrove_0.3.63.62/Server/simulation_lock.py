"""Reentrant simulation mutex that gives pending world ticks the next turn."""
import threading
from collections import deque
from contextlib import contextmanager

class SimulationLock:
    def __init__(self):
        self.condition=threading.Condition()
        self.owner=None
        self.depth=0
        self.ticks=0
        self.requests=deque()
        self.local=threading.local()

    @contextmanager
    def priority(self, tick=False):
        ident=threading.get_ident()
        with self.condition:
            if self.owner==ident:
                self.depth+=1
            else:
                if tick:self.ticks+=1
                token=object()
                if not tick:self.requests.append(token)
                try:
                    while self.owner is not None or (not tick and (self.ticks or self.requests[0] is not token)):
                        self.condition.wait()
                    self.owner=ident
                    self.depth=1
                    if not tick:self.requests.popleft()
                finally:
                    if tick:self.ticks-=1
        try:
            yield
        finally:
            with self.condition:
                self.depth-=1
                if not self.depth:
                    self.owner=None
                    self.condition.notify_all()

    def __enter__(self):
        # Context managers need per-thread stacks because eval can nest inside call.
        if not hasattr(self.local,'stack'):self.local.stack=[]
        context=self.priority();self.local.stack.append(context);return context.__enter__()

    def __exit__(self,*args):
        return self.local.stack.pop().__exit__(*args)
