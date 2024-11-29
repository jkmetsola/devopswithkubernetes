"""Provides a custom TCP server and a launcher to run it."""  # noqa: INP001

import sys
from http.server import SimpleHTTPRequestHandler
from socketserver import TCPServer


class TCPServerCustom(TCPServer):
    """Server that enabled reusing ports.

    It seems that when restarting the server, TCP packets are waited
    in TIME-WAIT state.

    This socket option tells the kernel that even if this port is busy (in
    the TIME_WAIT state), go ahead and reuse it anyway. If it is busy, but with
    another state, you will still get an address already in use error.

    Reference: https://serverfault.com/a/329846
    """

    allow_reuse_address = True
    allow_reuse_port = True


class TCPServerLauncher:
    """Launcher class for custom TCP server."""

    @staticmethod
    def run(port: int, handler: SimpleHTTPRequestHandler) -> None:  # noqa: D102
        with TCPServerCustom(("", port), handler) as httpd:
            sys.stdout.write(f"Server started in port {port}\n")
            sys.stdout.flush()
            httpd.serve_forever()
