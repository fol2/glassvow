"""Owner-controlled read-only GitHub bootstrap for DD1-HOST-BRIDGE-1.

HTTPS is the authenticated channel; hashes only establish byte identity. There
is deliberately no offline JSON, callback, alternate origin or redirect mode.
The host process is trusted code. Python objects are NOT security capabilities
against arbitrary code already executing inside that trusted host process.
"""
from __future__ import annotations

import base64
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
import http.client
import json
import os
import re
import ssl
from urllib.parse import quote

REPOSITORY = "fol2/glassvow"
OWNER = ("fol2", 105634418)
API_ROOT = "/repos/" + REPOSITORY
PROPOSAL = 5812756062
SELECTION = 5813769137
ACCEPTED_FIT = "5cd51a959ee98e68ede46d1d86d68f30240fdd80"
H = "5b6b3a718b8c6200d12d5c06c85702ea9a0f35c6"
H_ROOT = "research/p9-six-route/duskblade-first-proof-20260912/"
H_PINS = {"evidence_boundary.py": "a88db0791572f430ea3e5cde85683c8527cead39",
          "reference_kernel.py": "ee091fb503849117358b3691264fca71803f8bbc"}
MAX_RESPONSE = 2 * 1024 * 1024


class BridgeError(ValueError):
    pass


class ChannelUnavailable(BridgeError):
    pass


def need(ok, reason):
    if not ok:
        raise BridgeError(reason)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git_blob(raw):
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def decode(raw):
    def pairs(items):
        out = {}
        for k, v in items:
            need(k not in out, "duplicate JSON key")
            out[k] = v
        return out
    def bad(_):
        raise BridgeError("nonfinite JSON")
    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_constant=bad)
    except (UnicodeError, json.JSONDecodeError, TypeError) as exc:
        raise BridgeError("malformed JSON") from exc


def commit(value):
    need(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value), "exact commit required")
    return value


def natural(value, name):
    need(type(value) is int and value >= 0, "natural integer required: " + name)
    return value


def stamp(value):
    try:
        d = datetime.fromisoformat(value.replace("Z", "+00:00"))
        need(d.tzinfo is not None, "timezone required")
        return d.astimezone(timezone.utc)
    except (AttributeError, ValueError) as exc:
        raise BridgeError("invalid UTC timestamp") from exc


def owner_comment(value, number, issue):
    """Content validation only. A direct call does NOT authenticate retrieval."""
    natural(number, "comment id")
    need(isinstance(value, dict), "comment object required")
    user = value.get("user", {})
    need((user.get("login"), user.get("id")) == OWNER and
         value.get("author_association") == "OWNER", "wrong GitHub issuer")
    url = "https://api.github.com" + API_ROOT
    need(value.get("id") == number and value.get("url") == url + "/issues/comments/" + str(number)
         and value.get("issue_url") == url + "/issues/" + str(issue), "wrong comment/repository/scope")
    need(isinstance(value.get("body"), str) and 0 < len(value["body"].encode()) <= 65536,
         "missing or oversized comment body")
    need(stamp(value["created_at"]) <= stamp(value["updated_at"]), "comment chronology")
    return value["body"]


@dataclass(frozen=True)
class LiveRecord:
    """Internal result of verified TLS retrieval, never a workload input."""
    number: int
    issue: int
    body: str
    body_sha256: str
    updated_at: str
    observed_utc: str

    def document(self, schema):
        # Structured new host records use ONE complete JSON document, not prose
        # containing APPROVE or a selected convenient fragment of a comment.
        doc = decode(self.body)
        need(isinstance(doc, dict) and doc.get("schema") == schema, "wrong host record schema")
        return doc


class GitHubReadOnly:
    """Fixed-origin GET only, existing host token only; no credential discovery."""
    def __init__(self):
        self._token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
        self.observations = []

    def close(self):
        self._token = None  # Workload receives neither this client nor its env.

    def _get(self, suffix):
        need(isinstance(suffix, str) and suffix.startswith("/") and
             not any(x in suffix for x in ("\r", "\n", "#", "..")), "invalid fixed-origin request")
        headers = {"Accept": "application/vnd.github+json", "User-Agent": "DD1-HOST-BRIDGE-1",
                   "X-GitHub-Api-Version": "2022-11-28", "Cache-Control": "no-cache"}
        if self._token:
            headers["Authorization"] = "Bearer " + self._token
        observation = {'path': API_ROOT + suffix, 'started_utc': datetime.now(timezone.utc).isoformat(),
                       'result': 'REQUEST_STARTED'}
        self.observations.append(observation)
        connection = http.client.HTTPSConnection("api.github.com", timeout=8,
                                                 context=ssl.create_default_context())
        try:
            connection.request("GET", API_ROOT + suffix, headers=headers)
            response = connection.getresponse()
            need(response.status == 200, "GitHub GET status " + str(response.status))
            need(response.getheader("Content-Type", "").startswith("application/json"), "non-JSON GitHub response")
            raw = response.read(MAX_RESPONSE + 1)
            need(len(raw) <= MAX_RESPONSE, "oversized GitHub response")
            observed = datetime.now(timezone.utc).isoformat()
            observation.update(status=response.status, bytes=len(raw), sha256=sha(raw),
                               observed_utc=observed, result="RECEIVED")
            return decode(raw), observed
        except (OSError, http.client.HTTPException) as exc:
            observation.update(result="UNAVAILABLE", error_type=type(exc).__name__)
            # Do not publish exception request/header data or any credential.
            raise ChannelUnavailable("api.github.com HTTPS GET unavailable: " + type(exc).__name__) from None
        finally:
            connection.close()

    def comment(self, number, issue):
        natural(number, "comment id")
        obj, now = self._get("/issues/comments/" + str(number))
        body = owner_comment(obj, number, issue)
        need(stamp(obj["updated_at"]) <= stamp(now), "future authority record")
        return LiveRecord(number, issue, body, sha(body.encode()), obj["updated_at"], now)

    def file(self, head, path, blob=None):
        commit(head)
        need(isinstance(path, str) and not path.startswith("/") and
             all(p not in ("", ".", "..") for p in path.split("/")), "unsafe repository path")
        obj, _ = self._get("/contents/" + quote(path, safe="/") + "?ref=" + head)
        need(isinstance(obj, dict) and obj.get("type") == "file" and obj.get("path") == path
             and obj.get("encoding") == "base64", "missing complete repository file")
        try:
            raw = base64.b64decode("".join(obj["content"].split()), validate=True)
        except (ValueError, KeyError, TypeError) as exc:
            raise BridgeError("invalid repository file transport") from exc
        need(len(raw) == obj.get("size") and git_blob(raw) == obj.get("sha"), "Git file identity mismatch")
        need(blob is None or obj["sha"] == blob, "wrong pinned Git blob")
        return raw

    def selection(self):
        record = self.comment(SELECTION, 421)
        need("owner option A recorded" in record.body and str(PROPOSAL) in record.body
             and "source/inert" in record.body and "not an independent review" in record.body,
             "selection scope changed")
        return record

    def h_sources(self):
        return {name: self.file(H, H_ROOT + name, pin) for name, pin in H_PINS.items()}
