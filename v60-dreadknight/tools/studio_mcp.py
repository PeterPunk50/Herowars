"""Tiny stdio client for Roblox's own Studio MCP proxy (/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP).
Studio must be running with a place open and "Enable Studio as MCP server" on (Studio > Assistant > Settings > MCP Servers).
usage: studio_mcp.py list                                 -> print the tools Studio exposes
       studio_mcp.py studios                              -> print the connected Studio instances
       studio_mcp.py call <tool> '<json args>' [name]     -> call one tool; studio_id is filled in (the Studio whose name contains `name`, else the only one)
       studio_mcp.py luau <file.luau> [name] [Edit|Server|Client] -> run a Luau file with execute_luau and print the result
       studio_mcp.py shot <out.png> [name]                -> screen_capture to a PNG
Written 2026-10-14 (HeroWars); the protocol is plain JSON-RPC lines over stdin/stdout. The proxy needs a few seconds to meet Studio."""
import json, subprocess, sys, time, select, base64

BIN = '/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP'


class Client:
    def __init__(self):
        self.p = subprocess.Popen([BIN, '--stdio'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
        self.n = 0
        self.request('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {}, 'clientInfo': {'name': 'claude-code', 'version': '1'}})
        self.send({'jsonrpc': '2.0', 'method': 'notifications/initialized'})

    def send(self, msg):
        self.p.stdin.write(json.dumps(msg) + '\n'); self.p.stdin.flush()

    def request(self, method, params=None, timeout=120):
        self.n += 1; rid = self.n
        self.send({'jsonrpc': '2.0', 'id': rid, 'method': method, 'params': params or {}})
        end = time.time() + timeout
        while time.time() < end:
            r, _, _ = select.select([self.p.stdout], [], [], 1.0)
            if not r: continue
            line = self.p.stdout.readline()
            if not line: raise RuntimeError('StudioMCP closed')
            msg = json.loads(line)
            if msg.get('id') == rid: return msg
        raise TimeoutError(method)

    def tool(self, name, args=None, timeout=300):
        return self.request('tools/call', {'name': name, 'arguments': args or {}}, timeout)

    def studios(self, wait=30):
        end = time.time() + wait
        while True:
            r = self.tool('list_roblox_studios')
            try: s = json.loads(r['result']['content'][0]['text'])['studios']
            except Exception: s = []
            if s or time.time() > end: return s
            time.sleep(2)

    def pick(self, name=None):
        s = self.studios()
        if name: s = [x for x in s if name.lower() in json.dumps(x).lower()]
        if len(s) != 1: raise RuntimeError('need exactly one Studio, have: %s' % json.dumps(s))
        return s[0]['id']

    def close(self):
        try: self.p.stdin.close(); self.p.terminate()
        except Exception: pass


def text_of(r):
    out = []
    for c in r.get('result', {}).get('content', []):
        if c.get('type') == 'text': out.append(c['text'])
        else: out.append('<%s %d bytes>' % (c.get('type'), len(c.get('data', ''))))
    return '\n'.join(out) if out else json.dumps(r)


if __name__ == '__main__':
    c = Client(); cmd = sys.argv[1]
    try:
        if cmd == 'list':
            time.sleep(3); print(json.dumps(c.request('tools/list'), indent=1))
        elif cmd == 'studios':
            print(json.dumps(c.studios(), indent=1))
        elif cmd == 'call':
            args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
            args.setdefault('studio_id', c.pick(sys.argv[4] if len(sys.argv) > 4 else None))
            print(text_of(c.tool(sys.argv[2], args)))
        elif cmd == 'luau':
            code = open(sys.argv[2]).read()
            sid = c.pick(sys.argv[3] if len(sys.argv) > 3 else None)
            dm = sys.argv[4] if len(sys.argv) > 4 else 'Edit'
            print(text_of(c.tool('execute_luau', {'code': code, 'studio_id': sid, 'datamodel_type': dm})))
        elif cmd == 'shot':
            sid = c.pick(sys.argv[3] if len(sys.argv) > 3 else None)
            r = c.tool('screen_capture', {'studio_id': sid})
            for x in r['result']['content']:
                if x.get('type') == 'image': open(sys.argv[2], 'wb').write(base64.b64decode(x['data'])); print('wrote', sys.argv[2])
                else: print(x.get('text', ''))
    finally:
        c.close()
