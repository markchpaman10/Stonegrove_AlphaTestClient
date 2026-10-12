"""Ephemeral map presence; character names come from authenticated saved slots."""
import math
import threading
import time
from collections import OrderedDict


class Presence:
    ttl = 15.0

    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.players = {}
        self.names = OrderedDict()
        self.lock = threading.Lock()

    def character_name(self, user, slot):
        with self.lock:
            key = (user, slot)
            if key in self.names:
                self.names.move_to_end(key)
                return self.names[key][0]

    def remember_name(self, user, slot, name, revision=0):
        # Ordinary heartbeats never reread/parse the potentially large save blob.
        # Hydration cannot overwrite a newer name committed by a concurrent save.
        with self.lock:
            key = (user, slot)
            if key not in self.names or revision >= self.names[key][1]:
                self.names[key] = (name, revision)
            self.names.move_to_end(key)
            while len(self.names) > 3072:
                self.names.popitem(last=False)
            return self.names[key][0]

    def _prune(self, now):
        for user in list(self.players):
            if now - self.players[user]['seen'] >= self.ttl:
                del self.players[user]

    def heartbeat(self, user, owner, name, body):
        for key in ('worldId', 'regionId'):
            if not isinstance(body.get(key), str) or not 1 <= len(body[key]) <= 120 or any(ord(c) < 32 for c in body[key]):
                raise ValueError('Invalid map identity')
        for key in ('x', 'y', 'mapX', 'mapY'):
            n = body.get(key)
            if type(n) not in (int, float) or not math.isfinite(n) or not 0 <= n <= 10000000:
                raise ValueError('Invalid position')
        if body.get('area') not in ('overworld', 'cave'):
            raise ValueError('Invalid area')
        cave = body.get('caveId', 0)
        if type(cave) is not int or not 0 <= cave <= 1000000 or (body['area'] == 'cave' and cave == 0) or (body['area'] == 'overworld' and cave != 0):
            raise ValueError('Invalid cave')
        seed = body.get('caveSeed', 0)
        if type(seed) is not int or not 0 <= seed <= 2147483647 or (body['area'] == 'cave' and seed == 0) or (body['area'] == 'overworld' and seed != 0):
            raise ValueError('Invalid cave instance')
        record = {key: body[key] for key in ('worldId', 'regionId', 'x', 'y', 'mapX', 'mapY', 'area')}
        record.update(id=user, name=''.join(c if ord(c) >= 32 else ' ' for c in name)[:80], caveId=cave, caveSeed=seed)
        now = self.clock()
        with self.lock:
            self._prune(now)
            if user not in self.players and len(self.players) >= 1024:
                raise OverflowError('Presence capacity reached')
            self.players[user] = {'owner': owner, 'seen': now, 'record': record, 'slot': body.get('slot')}
            return [value['record'].copy() for key, value in sorted(self.players.items())
                    if key != user and value['record']['worldId'] == record['worldId']]

    def leave(self, user, owner):
        with self.lock:
            value = self.players.get(user)
            if value and value['owner'] == owner:
                del self.players[user]
