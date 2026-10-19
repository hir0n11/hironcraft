"""Run each Lua 5.1 harness in an isolated runtime; PYTHONPATH supplies lupa."""
import sys
from pathlib import Path
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parent.parent
import os
os.chdir(root)
paths = [Path(p) for p in sys.argv[1:]] or sorted(Path('scripts').glob('Test*.lua'))
failures = []
for path in paths:
    lua = LuaRuntime(encoding=None)
    try:
        lua.execute(b"os.setlocale('C'); arg={}; table.unpack=table.unpack or unpack")
        # The UI harnesses normally use Lua 5.4's UTF-8 library. Keep strict
        # validation while checking the addon's actual Lua 5.1 runtime.
        lua.globals()[b'utf8'] = lua.table_from({b'len': lambda s: len(s.decode('utf-8'))})
        if path.name == 'TestOrderStatusMerge.lua':
            lua.execute(b"arg[1]='Customer/OrderFulfillment.lua'")
        lua.execute(b"assert(loadfile(...))()", str(path).replace('\\', '/').encode())
        print('PASS', path.name, flush=True)
    except Exception as exc:
        failures.append(path.name)
        print('FAIL', path.name, str(exc).encode('ascii', 'backslashreplace').decode(), flush=True)
print(f'{len(paths)-len(failures)}/{len(paths)} passed; failures: {failures}')
sys.exit(bool(failures))
