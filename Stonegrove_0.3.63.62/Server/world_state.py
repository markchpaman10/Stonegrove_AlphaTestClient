"""Discard generated runtime snapshots before old JSON is passed to Lua."""
ROOM_KEYS={'placedContainers','groundItems','gravestones','burialGraves','campfires','pendingRuneDrops','graveSerial','graveRevision','entry','recoveryPoint'}
def migrate(document):
    if not isinstance(document,dict):raise ValueError('Invalid shared-world save')
    for entry in document.get('entries',[]):
        if entry.get('key')=='schemaVersion' and entry.get('value',0)>3:
            raise ValueError('Shared-world save uses a newer schema; run a newer server before loading it')
    for entry in document.get('entries',[]):
        if entry.get('key')=='rooms':
            for room in entry['value'].get('entries',[]):
                rows=room['value'].get('entries',[])
                room['value']['entries']=[e for e in rows if e.get('key') in ROOM_KEYS]
    return document
