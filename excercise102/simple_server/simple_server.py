"""Simple server tool."""

import http.server
import os
import socketserver
import sys

PORT = int(os.getenv("PORT", "8000"))

with socketserver.TCPServer(("", PORT), http.server.SimpleHTTPRequestHandler) as httpd:
    sys.stdout.write(f"Server started in port {PORT}\n")
    sys.stdout.flush()
    httpd.serve_forever()
