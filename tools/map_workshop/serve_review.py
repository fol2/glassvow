"""Serve the existing Tailnet review with capacity for a browser's media burst."""

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class ReviewServer(ThreadingHTTPServer):
    # HTTP/2 proxy requests arrive together; the stdlib default queue of five
    # can reject connections before a handler starts, producing Tailnet 502s.
    request_queue_size = 128


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[2]
    handler = partial(SimpleHTTPRequestHandler, directory=str(root))
    with ReviewServer(("127.0.0.1", 8766), handler) as server:
        print(f"Serving Glassvow review from {root} on localhost:8766", flush=True)
        server.serve_forever()
