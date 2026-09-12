#!/usr/bin/env python3
"""Serve the generated pages and the logs they link to, on localhost only.

    serve.py [PAGES_DIR] [--port 8080]

PAGES_DIR defaults to /data/ythierry/MCC26logs/web, the folder that holds one
page set per subfolder (`campaign/` from build.py, `order-sweep/` from
libHSC's sweep_pages.py); its index.html lists them. Binds 127.0.0.1: nobody
but this machine reaches it, and a remote reader gets in through an SSH
tunnel (`ssh -N -L 8080:localhost:8080 <host>`), which is the only way the
pages, and through them the log files, leave the disk. Pages are served from
PAGES_DIR; `/logs/<absolute path>` returns a log as plain text, provided the
path lies under one of the directories listed in a `roots.json` of PAGES_DIR
or of one of its subfolders (written by the page builders from the result
sets' log directories, re-read at every request so a rebuild needs no
restart). Anything else is 404.
"""

import argparse
import http.server
import json
import os
import urllib.parse


class Handler(http.server.SimpleHTTPRequestHandler):
    pages_dir = "."

    def do_GET(self) -> None:
        path = urllib.parse.unquote(urllib.parse.urlparse(self.path).path)
        parts = path.split("/", 3)
        if len(parts) == 4 and parts[2] == "logs":
            # Generated pages use relative links from their page-set folder.
            path = "/logs/" + parts[3]
        if path.startswith("/logs/"):
            return self.send_log(os.path.abspath(path[len("/logs"):]))
        return super().do_GET()

    def roots(self):
        """Read at every request: a rebuild may add log directories while the server runs."""
        files = [os.path.join(self.pages_dir, "roots.json")]
        try:
            files += [os.path.join(self.pages_dir, d, "roots.json") for d in sorted(os.listdir(self.pages_dir))
                      if os.path.isdir(os.path.join(self.pages_dir, d))]
        except OSError:
            pass
        roots = []
        for rf in files:
            try:
                with open(rf) as f:
                    roots += [os.path.abspath(r) for r in json.load(f)]
            except (OSError, ValueError):
                continue
        return roots

    def send_log(self, path):
        if not any(path.startswith(r.rstrip("/") + "/") for r in self.roots()) or not os.path.isfile(path):
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
    ap.add_argument("pages", nargs="?", default="/data/ythierry/MCC26logs/web")
    ap.add_argument("--port", type=int, default=8080)
    args = ap.parse_args()
    Handler.pages_dir = os.path.abspath(args.pages)
    os.chdir(args.pages)
    print(f"serving {args.pages} on http://127.0.0.1:{args.port}/ ; log roots re-read from its roots.json files at each request")
    http.server.ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
