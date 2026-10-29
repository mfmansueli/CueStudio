#!/usr/bin/env python3
"""Loopback-only Firebase benchmark. Config/results stay under ignored build/, outside the iOS app."""
import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from benchmark import ROOT, load_cases

ASSETS = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--port', type=int, default=8768)
    args = parser.parse_args()
    config = json.loads(args.config.read_text())
    if config.get('firebase', {}).get('projectId') != 'cue-script-ai-lab':
        raise ValueError('This experiment must use the isolated cue-script-ai-lab project')
    cases = load_cases()
    output = ROOT / 'build/firebase-quality/results.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    ledger = output.with_name('agent-platform-budget.json')
    origin = f'http://127.0.0.1:{args.port}'

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass  # Never log configuration, App Check debug tokens, or request bodies.

        def reply(self, body, kind='application/json', status=200):
            data = body.encode() if isinstance(body, str) else body
            self.send_response(status)
            self.send_header('Content-Type', kind)
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.headers.get('Host') != f'127.0.0.1:{args.port}':
                return self.reply('{}', status=403)
            if self.path == '/config.json':
                return self.reply(json.dumps(config))
            if self.path == '/cases.json':
                return self.reply(json.dumps(cases, ensure_ascii=False))
            assets = {'/': ('index.html', 'text/html; charset=utf-8'), '/client.js': ('client.js', 'text/javascript'),
                      '/writerFlow.mjs': ('writerFlow.mjs', 'text/javascript'),
                      '/voiceContext.mjs': ('voiceContext.mjs', 'text/javascript'), '/FirebaseProbe.mjs': ('FirebaseProbe.mjs', 'text/javascript')}
            if self.path not in assets:
                return self.reply('{}', status=404)
            name, kind = assets[self.path]
            self.reply((ASSETS / name).read_bytes(), kind)

        def do_POST(self):
            if self.path not in ('/results', '/reserve') or self.headers.get('Origin') != origin or self.headers.get('Host') != f'127.0.0.1:{args.port}':
                return self.reply('{}', status=403)
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 2_000_000:
                return self.reply('{}', status=413)
            try:
                samples = json.loads(self.rfile.read(length))
                if self.path == '/reserve':
                    if samples.get('model') not in ('gemini-3.5-flash', 'gemini-3.8-flash'):
                        return self.reply('{}', status=400)
                    used = json.loads(ledger.read_text()).get('used', 0) if ledger.exists() else 0
                    if used >= 8:
                        return self.reply('{"error":"Batch limit reached"}', status=429)
                    temporary = ledger.with_suffix('.tmp')
                    temporary.write_text(json.dumps({'used': used + 1, 'limit': 8}))
                    temporary.replace(ledger)
                    return self.reply(json.dumps({'used': used + 1, 'limit': 8}))
                if not isinstance(samples, list) or len(samples) > 20:
                    raise ValueError('Unexpected batch')
                previous = json.loads(output.read_text()) if output.exists() else []
                merged_by_id = {x['id']: x for x in previous}
                merged_by_id.update({x['id']: x for x in samples})
                merged = list(merged_by_id.values())
                temporary = output.with_suffix('.tmp')
                temporary.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + '\n')
                temporary.replace(output)
                self.reply('{"saved":true}')
            except (ValueError, KeyError, TypeError):
                self.reply('{}', status=400)

    print(f'Firebase benchmark: {origin} (no API request until Run is clicked)', flush=True)
    HTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()
