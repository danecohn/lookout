from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import sys
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        page='B' if self.path=='/b' else 'A'
        body=('<!doctype html><meta charset="utf-8"><title>Lookout Fixture '+page+'</title><style>body{font:20px system-ui;padding:60px;background:#eef5ff}a{color:#147ce5}</style><h1>Lighthouse '+page+'</h1><p>An owned local fixture for Cohnsoft Lookout.</p><a target="_blank" href="/b">Open a connected tab</a><p><a href="/b">Navigate to B</a></p><input placeholder="Test unsaved form"><p><a download href="/download">Download fixture</a></p>').encode()
        if self.path=='/download':
            body=b'Cohnsoft Lookout download fixture\n';self.send_response(200);self.send_header('Content-Disposition','attachment; filename="lookout-fixture.txt"');self.send_header('Content-Type','application/octet-stream')
        else:
            self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8')
        self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
ThreadingHTTPServer(('127.0.0.1',int(sys.argv[1]) if len(sys.argv)>1 else 4397),Handler).serve_forever()
