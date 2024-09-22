#!/usr/bin/env python3

"""Starts a simple HTTP server that serves the content of a specified log file."""

import argparse
import http.server
import socketserver
import sys
from pathlib import Path


class LogRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Request handler that serves the content of a log file."""

    def _get_log_content(self) -> str:
        with Path(LOG_FILE).open() as file:
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
    def run(port: int) -> None:
        """Start the server."""
        with Path(LOG_FILE).open("w") as file:
            file.write("\n")
        with socketserver.TCPServer(("", port), LogRequestHandler) as httpd:
            sys.stdout.write(f"Server started in port {port}\n")
            sys.stdout.flush()
            httpd.serve_forever()

    @staticmethod
    def parse_args() -> argparse.ArgumentParser:
        """Set up command-line argument parser."""
        parser = argparse.ArgumentParser(description="Simple Log Server")
        parser.add_argument(
            "--port", type=int, required=True, help="Port to run the server on"
        )
        parser.add_argument(
            "--logfile", type=str, required=True, help="Path to the log file to serve"
        )
        return parser.parse_args()


if __name__ == "__main__":
    args = LogServer.parse_args()
    LOG_FILE = args.logfile
    LogServer.run(port=args.port)