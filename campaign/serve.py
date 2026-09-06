#!/usr/bin/env python3
"""Serve the campaign pages and the logs they link to, on localhost only.

    serve.py PAGES_DIR [--port 8080]

Binds 127.0.0.1: nobody but this machine reaches it, and a remote reader
gets in through an SSH tunnel (`ssh -N -L 8080:localhost:8080 <host>`),
which is the only way the pages, and through them the log files, leave the
disk. `/` and `/<page>.html` come from PAGES_DIR; `/logs/<absolute path>`
returns a log as plain text, provided the path lies under one of the
directories listed in PAGES_DIR/roots.json (written by build.py from the
result sets' log directories). Anything else is 404.
"""

import argparse
import http.server
import json
import os
import urllib.parse


class Handler(http.server.SimpleHTTPRequestHandler):
    roots = []

    def do_GET(self):
        path = urllib.parse.unquote(urllib.parse.urlparse(self.path).path)
        if path.startswith("/logs/"):
            return self.send_log(os.path.abspath(path[len("/logs"):]))
        return super().do_GET()

    def send_log(self, path):
        if not any(path.startswith(r.rstrip("/") + "/") for r in self.roots) or not os.path.isfile(path):
            self.send_error(404, "not a log under the configured roots")
            return
        size = os.path.getsize(path)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(size))
        self.end_headers()
        with open(path, "rb") as f:
            while chunk := f.read(1 << 16):
                self.wfile.write(chunk)

    def log_message(self, fmt, *args):
        pass


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("pages")
    ap.add_argument("--port", type=int, default=8080)
    args = ap.parse_args()
    roots_file = os.path.join(args.pages, "roots.json")
    if os.path.exists(roots_file):
        with open(roots_file) as f:
            Handler.roots = [os.path.abspath(r) for r in json.load(f)]
    os.chdir(args.pages)
    print(f"serving {args.pages} on http://127.0.0.1:{args.port}/ ; logs from {Handler.roots}")
    http.server.ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
