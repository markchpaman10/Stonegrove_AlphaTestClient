"""Overlay unacknowledged corpse transfers on stale character saves."""
import json
from pathlib import Path


def protect(service, user, slot, character):
    from camps import pack, unpack
    if service.simulation:
        ledger = unpack(service.simulation.call('grave_ledger', {'id': user, 'slot': slot}))
    else:
        path = Path(service.db).parent / 'shared_world.json'
        world = unpack(json.loads(path.read_text(encoding='utf-8'))) if path.is_file() else {}
        ledger = world.get('graveLedger', {}).get(str(user)+':'+str(slot))
    if not ledger:
        return character
    saved = unpack(json.loads(character['save']))
    if saved.get('graveEpoch', 0) != ledger['graveEpoch']:
        for field in ('bags', 'equipment', 'equipmentItems', 'equipmentSockets', 'potionBelt', 'graveEpoch'):
            saved[field] = ledger.get(field, {})
        saved.setdefault('player', {}).update(ledger['player'])
        saved['activeBag'] = 1
        for name, skill in ledger.get('skills', {}).items():
            old = saved.setdefault('skills', {}).get(name, {})
            if old.get('xp', 0) < skill.get('xp', 0):
                saved['skills'][name] = skill
        return dict(character, save=json.dumps(pack(saved), separators=(',', ':')))
    return character
