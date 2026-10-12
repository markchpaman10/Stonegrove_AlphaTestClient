"""Build-time validation for the Stonegrove Render deployment. Never opens accounts.sqlite3."""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parent.parent
required = [
    'Server/server.py','Server/storage.py','Server/presence.py','Server/simulation.py',
    'Server/headless.lua','Server/shared_world.lua','Server/camps.py','Server/camp_rules.lua',
    'game/admin_rules.lua','game/resource_placement.lua','game/fieldcraft.lua','game/fieldcraft_content.lua','game/fieldcraft_ui.lua','game/survival_foraging.lua','game','assets',
    'current.lua','event_data.lua','item_data.lua','monster_data.lua','npc_data.lua','quest_data.lua'
]
missing = [x for x in required if not (ROOT/x).exists()]
if missing:
    raise SystemExit('Missing deployment files: ' + ', '.join(missing))
sys.path.insert(0, str(ROOT/'Server'))
from simulation import Simulation
sim = Simulation(ROOT, data_dir=None)
try:
    ready = sim.eval('return "stonegrove-render-ready"')
    if ready != 'stonegrove-render-ready':
        raise RuntimeError('Lua simulation readiness check returned unexpected data')
finally:
    sim.close()
print('Validated simulation files and compatible Lua runtime.')
