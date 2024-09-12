#!/usr/bin/env python3

"""Starts a simple HTTP server that serves the content of a specified log file."""

import http.server
import socketserver
import sys
from pathlib import Path

from environment.environment import Environment


class LogRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Request handler that serves the content of a log file."""

    LOG_FILE = Environment.log_file

    def _get_log_content(self) -> str:
        with Path(self.LOG_FILE).open() as file:
            return file.read()

    def do_GET(self) -> None:  # noqa: N802
        """Handle GET requests by reading the log file and returning its content."""
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        self.wfile.write(self._get_log_content().encode("utf-8"))


class LogServer:
    """A simple log server that serves the content of a specified log file."""

    @staticmethod
    def run() -> None:
        """Start the server."""
        port = Environment().port
        with socketserver.TCPServer(("", port), LogRequestHandler) as httpd:
            sys.stdout.write(f"Server started in port {port}\n")
            sys.stdout.flush()
            httpd.serve_forever()
