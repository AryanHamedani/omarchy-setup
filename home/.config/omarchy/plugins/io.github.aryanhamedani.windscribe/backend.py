#!/usr/bin/python3
"""Small, unprivileged JSON adapter for the native Windscribe panel."""
import configparser
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

CONFIG = Path.home() / '.config/Windscribe/windscribe_cli.conf'
CLI = '/usr/bin/windscribe-cli'
CLI_LOCK = Path(os.environ.get('XDG_RUNTIME_DIR', str(CONFIG.parent))) / 'windscribe-panel-cli.lock'
BOOLS = {'Autoconnect', 'AllowLANTraffic', 'CircumventCensorship', 'SplitTunnelingEnabled'}
PROTOCOLS = ['WireGuard', 'Stealth', 'WStunnel', 'UDP', 'TCP']

def cli(*args, timeout=8):
    with CLI_LOCK.open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        proc = subprocess.run([CLI, *args], capture_output=True, text=True, timeout=timeout)
    if proc.returncode:
        raise RuntimeError((proc.stdout or proc.stderr or 'Windscribe command failed').strip()[:400])
    return re.sub(r'\x1b\[[0-9;]*m', '', proc.stdout).strip()

def parse_status(text):
    fields = {}
    for line in text.splitlines():
        if ': ' in line:
            key, value = line.lstrip('*').split(': ', 1)
            fields[key] = value
    connection = fields.get('Connect state', '')
    firewall = fields.get('Firewall state', 'Unknown')
    state = 'unknown'
    if connection.startswith('Connected:'):
        state = 'testing' if '*Connect state:' in text else 'connected'
    elif connection == 'Disconnected':
        state = 'blocked' if firewall in ('On', 'Always On') else 'disconnected'
    elif connection and any(s in connection.lower() for s in ('connecting', 'disconnecting', 'reconnecting')):
        state = 'connecting'
    return {'state': state, 'location': connection.removeprefix('Connected: ').strip() if connection.startswith('Connected:') else '',
            'firewall': firewall, 'ip': fields.get('VPN IP', ''), 'protocol': fields.get('Protocol', ''),
            'login': fields.get('Login state', 'Unknown'), 'usage': fields.get('Data usage', '')}

def parse_locations(text):
    result = []
    for line in text.splitlines():
        label = re.sub(r'\s+\([^)]*\)\s*$', '', line.strip())
        parts = label.split(' - ')
        if len(parts) >= 3:
            result.append({'id': parts[-1], 'label': label, 'city': parts[-2], 'region': parts[0], 'us': parts[0].startswith('US ')})
    return sorted(result, key=lambda row: (not row['us'], row['label']))

def domain(value):
    value = value.strip().lower().rstrip('.')
    if any(c.isspace() for c in value): raise ValueError('Enter a hostname without spaces or a URL.')
    try:
        ipaddress.ip_address(value)
    except ValueError:
        pass
    else:
        raise ValueError('Enter a hostname; country IP ranges are managed automatically.')
    value = value.encode('idna').decode('ascii')
    if len(value) > 253 or '.' not in value or not all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', label) for label in value.split('.')):
        raise ValueError('Enter a valid hostname, for example app.example.ir. Wildcards are not supported.')
    return value

def is_network(value):
    try: ipaddress.ip_network(value); return True
    except ValueError: return False

def change_domains(routes, action, value):
    value = domain(value)
    if action == 'remove': return [r for r in routes if r != value]
    if action != 'add': raise ValueError('Unknown domain action')
    if value in routes: return routes
    if sum(not is_network(r) for r in routes) >= 50:
        raise ValueError('Windscribe supports at most 50 hostname exceptions. Remove one first.')
    return routes + [value]

def setting_changes(key, value):
    if key in BOOLS and value in ('true', 'false'): return {key: value}
    if key == 'ManualConnectionProtocol' and value in PROTOCOLS:
        return {'ConnectionMode': 'Manual', key: value, 'ManualConnectionPort': '443'}
    raise ValueError('Unsupported setting or value')

def read_preferences(text):
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read_string(text)
    c = dict(parser['Connection'])
    routes = [s.strip() for s in c.get('SplitTunnelingRoutes', '').split(',') if s.strip()]
    settings = {key: c.get(key, '') for key in BOOLS | {'AmneziawgPreset', 'ManualConnectionProtocol', 'ManualConnectionPort', 'ConnectedDNSMode', 'FirewallMode'}}
    settings['domains'] = [r for r in routes if not is_network(r)]
    settings['rangeCount'] = sum(is_network(r) for r in routes)
    return settings, routes

def edit_ini(text, changes):
    lines = text.splitlines(keepends=True)
    start = next((i for i,line in enumerate(lines) if line.strip() == '[Connection]'), None)
    if start is None: raise ValueError('Windscribe Connection section is missing')
    end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith('[')), len(lines))
    pending = dict(changes)
    for i in range(start + 1, end):
        key = lines[i].split('=',1)[0].strip()
        if key in pending:
            lines[i] = key + '=' + pending.pop(key) + '\n'
    if pending:
        if end and not lines[end - 1].endswith('\n'):
            lines[end - 1] += '\n'
        lines[end:end] = [key + '=' + value + '\n' for key,value in pending.items()]
    return ''.join(lines)

def mutate(make_changes):
    # Same lock used by the weekly country-range refresher.
    with (CONFIG.parent / '.iran-refresh.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        original = CONFIG.read_text()
        prefs, routes = read_preferences(original)
        changed = edit_ini(original, make_changes(prefs, routes))
        if changed == original: return
        if CONFIG.read_text() != original: raise RuntimeError('Settings changed concurrently. Please try again.')
        fd, name = tempfile.mkstemp(prefix='.windscribe-panel-', dir=CONFIG.parent)
        try:
            with os.fdopen(fd, 'w') as stream:
                stream.write(changed); stream.flush(); os.fsync(stream.fileno())
            os.replace(name, CONFIG)
        finally:
            if os.path.exists(name): os.unlink(name)

def dispatch(args):
    if args == ['status']:
        prefs,_ = read_preferences(CONFIG.read_text())
        return {'status': parse_status(cli('status')), 'settings': prefs}
    if args == ['catalog']:
        return {'locations': parse_locations(cli('locations')), 'presets': cli('amneziawg').splitlines()}
    if len(args) == 2 and args[0] == 'connect':
        location = args[1]
        if location != 'US' and location not in {r['id'] for r in parse_locations(cli('locations'))}:
            raise ValueError('Choose a location from the current Windscribe list.')
        return {'message': cli('connect', '-n', location)}
    if args == ['disconnect']: return {'message': cli('disconnect', '-n')}
    if len(args) == 3 and args[0] == 'set':
        changes = setting_changes(args[1], args[2])
        mutate(lambda p,r: changes)
        return {'message': 'Settings saved. Connection changes may reconnect the VPN.'}
    if len(args) == 2 and args[0] == 'preset':
        if args[1] not in cli('amneziawg').splitlines(): raise ValueError('Choose an available censorship preset.')
        mutate(lambda p,r: {'AmneziawgPreset': args[1]})
        return {'message': 'Censorship preset saved.'}
    if len(args) == 3 and args[0] == 'domain':
        mutate(lambda p,r: {'SplitTunnelingRoutes': ', '.join(change_domains(r,args[1],args[2]))})
        return {'message': 'Bypass list saved. DNS filtering is managed separately in R.O.B.E.R.T.'}
    if args == ['refresh-ranges']:
        proc = subprocess.run([str(Path.home()/'.local/bin/windscribe-refresh-iran')],capture_output=True,text=True,timeout=60)
        if proc.returncode: raise RuntimeError((proc.stderr or proc.stdout)[-400:])
        return {'message': proc.stdout.strip()}
    raise ValueError('Unknown operation')

def main():
    try: print(json.dumps({'ok': True, **dispatch(sys.argv[1:])}))
    except Exception as error:
        print(json.dumps({'ok': False, 'error': str(error)[:400]})); sys.exit(1)

if __name__ == '__main__': main()
