#!/usr/bin/env python3
"""Server that increments a counter each time it is accessed."""

import argparse
import http.server
import json
import socketserver
import sys
from pathlib import Path


class PingPongRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Serves the content of a specified log file and increments a counter."""

    def _get_counter_value(self) -> int:
        with Path(COUNTER_FILE).open() as file:
            return json.load(file)["counter"]

    def _set_counter_value(self, value: int) -> None:
        with Path(COUNTER_FILE).open("w") as file:
            json.dump({"counter": value}, file)

    def do_GET(self) -> None:  # noqa: N802
        """Handle GET request and serve the counter value."""
        self.send_response(200)
        self.send_header("Content-type", "application/json")
        self.end_headers()
        response = json.dumps({"message": f"pong {self._get_counter_value()}"})
        self.wfile.write(response.encode())
        self._set_counter_value(self._get_counter_value() + 1)


class PingPongServer:
    """Server to handle ping-pong requests."""

    @staticmethod
    def run(port: int) -> None:
        """Start the server."""
        with Path(COUNTER_FILE).open("w") as file:
            json.dump({"counter": 0}, file)
        with socketserver.TCPServer(("", port), PingPongRequestHandler) as httpd:
            sys.stdout.write(f"Server started in port {port}\n")
            sys.stdout.flush()
            httpd.serve_forever()

    @staticmethod
    def parse_args() -> argparse.Namespace:
        """Parse command-line arguments."""
        parser = argparse.ArgumentParser(description="PingPong Server")
        parser.add_argument(
            "--port", type=int, required=True, help="Port to run the server on"
        )
        parser.add_argument(
            "--counter-file", type=str, required=True, help="Counter file path"
        )
        return parser.parse_args()


if __name__ == "__main__":
    args = PingPongServer.parse_args()
    COUNTER_FILE = args.counter_file
    PingPongServer.run(args.port)
