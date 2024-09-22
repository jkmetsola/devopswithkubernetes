#!/usr/bin/env python3

"""Simple server tool."""

import argparse
import http.server
import socketserver
import sys
from pathlib import Path


class ProjectRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Request handler that serves the content of a log file."""

    def do_GET(self) -> None:  # noqa: N802
        """Handle GET requests by reading the log file and returning its content."""
        self.send_response(200)
        self.send_header("Content-type", "image/jpeg")
        self.end_headers()
        with Path.open(PICTURE_PATH, "rb") as file:
            self.wfile.write(file.read())


class ProjectServer:
    """Server to handle project requests."""

    @staticmethod
    def run(port: int) -> None:
        """Start the server."""
        with socketserver.TCPServer(("", port), ProjectRequestHandler) as httpd:
            sys.stdout.write(f"Server started in port {port}\n")
            sys.stdout.flush()
            httpd.serve_forever()

    @staticmethod
    def parse_args() -> argparse.Namespace:
        """Parse command line arguments."""
        parser = argparse.ArgumentParser(description="Simple server tool.")
        parser.add_argument(
            "--port", type=int, required=True, help="Port to run the server on."
        )
        parser.add_argument(
            "--picture-file",
            type=str,
            required=True,
            help="Path to the picture to serve.",
        )
        return parser.parse_args()


if __name__ == "__main__":
    args = ProjectServer.parse_args()
    PICTURE_PATH = args.picture_file
    ProjectServer.run(args.port)
