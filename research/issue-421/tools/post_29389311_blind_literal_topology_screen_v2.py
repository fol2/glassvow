#!/usr/bin/env python3
"""Run the preregistered source-blind literal topology screen."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import tempfile
import time
import unicodedata
from itertools import product
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PROTOCOL = ROOT / "protocols/post-29389311-blind-literal-topology-screen-v1.json"
RETRIEVAL = ROOT / "summaries/post-c802be36-primary-rule-retrieval-v2.json"
LEXICON = ROOT / "summaries/post-29389311-blind-literal-topology-lexicon-v1.json"
OUTPUT = ROOT / "summaries/post-29389311-blind-literal-topology-screen-v2.json"
SOURCE_DIR = Path("/tmp/glassvow-421-primary-rules-v2.Zopobg")

EXPECTED_HASHES = {
    PROTOCOL: "cfea59dd85c897292e026a38cfed6002d6218543fb4f006d21ab4f35650e36d9",
    RETRIEVAL: "c4fa11128c6769f59f744229cedf05f1f8414a94ba1e377b5b711dba6ea66d0c",
    LEXICON: "e9d7b530439fd37af3abf4d1be0d8322ed4238aadc998fa0cf0075121adba7cc",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_frozen_json(path: Path) -> dict:
    data = path.read_bytes()
    require(sha256(data) == EXPECTED_HASHES[path], f"hash mismatch: {path}")
    return json.loads(data)


def normalise(text: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", text).lower().split())


def pdf_passages(source_id: str, text: str) -> list[dict]:
    passages: list[dict] = []
    for page_number, page in enumerate(text.split("\f"), 1):
        blocks: list[list[str]] = []
        block: list[str] = []
        for line in page.splitlines() + [""]:
            if line.strip():
                block.append(line)
            elif block:
                blocks.append(block)
                block = []
        for passage_number, lines in enumerate(blocks, 1):
            value = normalise("\n".join(lines))
            passages.append(
                {
                    "identity": f"{source_id}:page:{page_number}:passage:{passage_number}",
                    "location": {"page": page_number, "passage": passage_number},
                    "normalised": value,
                }
            )
    return passages


def text_passages(source_id: str, text: str) -> list[dict]:
    return [
        {
            "identity": f"{source_id}:line:{line_number}",
            "location": {"line": line_number},
            "normalised": normalise(line),
        }
        for line_number, line in enumerate(text.splitlines(), 1)
        if line.strip()
    ]


def validate_lexicon(data: dict, protocol: dict) -> tuple[dict, dict, dict]:
    timings = protocol["topologyCodebook"]["timings"]
    targets = protocol["topologyCodebook"]["targetSurfaces"]
    transforms = protocol["topologyCodebook"]["transforms"]
    reports = data.get("reports", {})
    require(list(reports) == ["L1", "L2"], "blind report order mismatch")
    expected = {"L1": timings + targets, "L2": transforms}
    seen: set[str] = set()
    lexicons: dict[str, dict] = {}
    for report_id in ("L1", "L2"):
        report = reports[report_id]
        require(report.get("sourceExposure") == 0, f"{report_id} source exposure")
        lexicon = report.get("lexicon", {})
        require(list(lexicon) == expected[report_id], f"{report_id} label mismatch")
        compact = json.dumps(lexicon, ensure_ascii=True, separators=(",", ":"))
        require(sha256(compact.encode()) == report.get("reportSha256"), f"{report_id} report hash")
        for label, phrases in lexicon.items():
            require(isinstance(phrases, list) and 1 <= len(phrases) <= 3, f"{label} phrase count")
            require(phrases[0] == label.lower().replace("_", " "), f"{label} canonical phrase")
            for phrase in phrases:
                require(
                    isinstance(phrase, str)
                    and re.fullmatch(r"[a-z0-9]+(?: [a-z0-9]+){0,3}", phrase) is not None,
                    f"{label} phrase rule",
                )
                require(phrase not in seen, f"cross-label phrase reuse: {phrase}")
                seen.add(phrase)
        lexicons[report_id] = lexicon
    return (
        {label: lexicons["L1"][label] for label in timings},
        {label: lexicons["L1"][label] for label in targets},
        lexicons["L2"],
    )


def matched_labels(text: str, lexicon: dict[str, list[str]]) -> list[tuple[str, str]]:
    return [
        (label, next(phrase for phrase in phrases if phrase in text))
        for label, phrases in lexicon.items()
        if any(phrase in text for phrase in phrases)
    ]


def passage_keys(
    text: str,
    timings: dict[str, list[str]],
    targets: dict[str, list[str]],
    transforms: dict[str, list[str]],
) -> list[tuple[str, dict]]:
    timing_hits = matched_labels(text, timings)
    target_hits = matched_labels(text, targets)
    transform_hits = matched_labels(text, transforms)
    rows: list[tuple[str, dict]] = []
    for producer, target, transform, consumer in product(
        timing_hits, target_hits, transform_hits, timing_hits
    ):
        key = "|".join((producer[0], target[0], transform[0], consumer[0]))
        rows.append(
            (
                key,
                {
                    "producerTiming": producer[1],
                    "targetSurface": target[1],
                    "transform": transform[1],
                    "consumerTiming": consumer[1],
                },
            )
        )
    return rows


def retain_match(matches: dict, key: str, source_id: str, row: dict, cap: int = 5) -> None:
    retained = matches.setdefault(key, {}).setdefault(source_id, [])
    if len(retained) < cap and all(item["passageIdentity"] != row["passageIdentity"] for item in retained):
        retained.append(row)


def select_packet(
    matches: dict,
    publishers: dict[str, str],
    source_order: list[str],
    key_cap: int,
    passage_cap: int,
) -> tuple[list[dict], int]:
    supported: list[dict] = []
    for key, by_source in matches.items():
        publisher_count = len({publishers[source_id] for source_id in by_source})
        if len(by_source) < 2 or publisher_count < 2:
            continue
        passages = [row for source_id in source_order for row in by_source.get(source_id, [])]
        supported.append(
            {
                "key": key,
                "sourceCount": len(by_source),
                "publisherCount": publisher_count,
                "retainedPassageCount": len(passages),
                "passages": passages[:passage_cap],
            }
        )
    supported.sort(
        key=lambda item: (
            -item["sourceCount"],
            -item["publisherCount"],
            item["retainedPassageCount"],
            item["key"],
        )
    )
    return supported[:key_cap], len(supported)


def self_test() -> None:
    assert normalise("  Ａ\tB\nC  ") == "a b c"
    assert [(p["location"], p["normalised"]) for p in pdf_passages("S", "A\nB\n\nC\fD\n\nE\nF")] == [
        ({"page": 1, "passage": 1}, "a b"),
        ({"page": 1, "passage": 2}, "c"),
        ({"page": 2, "passage": 1}, "d"),
        ({"page": 2, "passage": 2}, "e f"),
    ]
    assert [(p["location"], p["normalised"]) for p in text_passages("S", "\nA\n \nB C")] == [
        ({"line": 2}, "a"),
        ({"line": 4}, "b c"),
    ]
    assert [key for key, _ in passage_keys("start foe delay", {"T": ["start"]}, {"G": ["foe"]}, {"X": ["delay"]})] == ["T|G|X|T"]
    assert passage_keys("start foe", {"T": ["start"]}, {"G": ["foe"]}, {"X": ["delay"]}) == []

    matches: dict = {}
    for key, sources in {
        "K0": ["A", "B", "C"],
        "K0B": ["A", "B", "D"],
        "K1": ["A", "B"],
        "K2": ["A", "B", "B"],
        "K3": ["A"],
        "K4": ["A", "B"],
        "K_SAME_PUBLISHER": ["A", "D"],
    }.items():
        for index, source_id in enumerate(sources):
            retain_match(matches, key, source_id, {"passageIdentity": f"{source_id}:{index}"})
    retain_match(matches, "K5", "A", {"passageIdentity": "A:0"})
    retain_match(matches, "K5", "A", {"passageIdentity": "A:0"})
    assert len(matches["K5"]["A"]) == 1
    for index in range(1, 7):
        retain_match(matches, "K5", "A", {"passageIdentity": f"A:{index}"})
    retain_match(matches, "K5", "B", {"passageIdentity": "B:0"})
    assert len(matches["K5"]["A"]) == 5
    packet, eligible = select_packet(
        matches,
        {"A": "P1", "B": "P2", "C": "P3", "D": "P1"},
        ["A", "B", "C", "D"],
        key_cap=4,
        passage_cap=2,
    )
    assert eligible == 6
    assert [item["key"] for item in packet] == ["K0", "K0B", "K1", "K4"]
    assert all(len(item["passages"]) <= 2 for item in packet)


def validate_controls() -> tuple[dict, dict, tuple[dict, dict, dict]]:
    protocol = load_frozen_json(PROTOCOL)
    retrieval = load_frozen_json(RETRIEVAL)
    lexicon = load_frozen_json(LEXICON)
    require(protocol["protocolId"] == lexicon["protocolId"], "protocol identity mismatch")
    identities = {item["id"]: item for item in protocol["sourceIdentities"]}
    documents = retrieval["documents"]
    require([document["queryId"] for document in documents] == list(identities), "source order mismatch")
    for document in documents:
        identity = identities[document["queryId"]]
        require(document["publisher"] == identity["publisher"], "publisher mismatch")
        require(document["extractedTextSha256"] == identity["extractedTextSha256"], "source hash mismatch")
    return protocol, retrieval, validate_lexicon(lexicon, protocol)


def run_live(source_dir: Path, output: Path) -> dict:
    require(not output.exists(), f"refusing to overwrite sole live output: {output}")
    started = time.monotonic()
    self_test()
    protocol, retrieval, lexicons = validate_controls()
    timings, targets, transforms = lexicons
    deadline = started + protocol["deterministicExtraction"]["wallTimeSeconds"]
    matches: dict = {}
    passage_count = 0
    publishers: dict[str, str] = {}
    source_order: list[str] = []

    for document in retrieval["documents"]:
        source_id = document["queryId"]
        source_order.append(source_id)
        publishers[source_id] = document["publisher"]
        source_path = source_dir / f"{source_id}.txt"
        data = source_path.read_bytes()
        require(sha256(data) == document["extractedTextSha256"], f"source hash mismatch: {source_id}")
        text = data.decode("utf-8")
        passages = text_passages(source_id, text) if document["mediaType"] == "text/plain" else pdf_passages(source_id, text)
        passage_count += len(passages)
        for passage in passages:
            require(time.monotonic() <= deadline, "live wall-time cap exceeded")
            for key, literals in passage_keys(passage["normalised"], timings, targets, transforms):
                retain_match(
                    matches,
                    key,
                    source_id,
                    {
                        "sourceId": source_id,
                        "publisher": document["publisher"],
                        "passageIdentity": passage["identity"],
                        "location": passage["location"],
                        "passageSha256": sha256(passage["normalised"].encode()),
                        "matchedLiterals": literals,
                    },
                )

    packet, supported_count = select_packet(
        matches,
        publishers,
        source_order,
        protocol["deterministicExtraction"]["packetCapKeys"],
        protocol["deterministicExtraction"]["packetCapPassagesPerKey"],
    )
    for item in packet:
        producer, target, transform, consumer = item["key"].split("|")
        item.update(
            {
                "producerTiming": producer,
                "targetSurface": target,
                "transform": transform,
                "consumerTiming": consumer,
                "packetPassageCount": len(item["passages"]),
            }
        )
    result = {
        "schemaVersion": 1,
        "protocolId": protocol["protocolId"],
        "outcome": "SUCCESS_PASSAGE_PACKET" if packet else "FUTILITY_NO_TWO_SOURCE_TWO_PUBLISHER_LITERAL_SUPPORT",
        "inputHashes": {
            "protocolSha256": EXPECTED_HASHES[PROTOCOL],
            "retrievalRecordSha256": EXPECTED_HASHES[RETRIEVAL],
            "lexiconSha256": EXPECTED_HASHES[LEXICON],
        },
        "accounting": {
            "sourcesScanned": len(source_order),
            "passagesScanned": passage_count,
            "observedLiteralKeys": len(matches),
            "supportedLiteralKeys": supported_count,
            "selectedKeys": len(packet),
            "mechanicalCorrectionsUsed": 1,
            "simulatorRows": 0,
            "ledgerReads": 0,
            "ledgerWrites": 0,
            "protectedSeedRows": 0,
            "candidatesConstructed": 0,
            "mlRlOptimiserRuns": 0,
        },
        "rankedPacket": packet,
    }
    encoded = (json.dumps(result, ensure_ascii=True, indent=2, sort_keys=True) + "\n").encode()
    require(len(encoded) <= protocol["deterministicExtraction"]["outputByteCap"], "output byte cap exceeded")
    require(time.monotonic() <= deadline, "live wall-time cap exceeded")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as temporary:
        temporary.write(encoded)
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, output)
    return {
        "outcome": result["outcome"],
        "output": str(output),
        "outputBytes": len(encoded),
        "outputSha256": sha256(encoded),
        "wallTimeSeconds": round(time.monotonic() - started, 6),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--self-test", action="store_true")
    action.add_argument("--run", action="store_true")
    parser.add_argument("--source-dir", type=Path, default=SOURCE_DIR)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        validate_controls()
        print(json.dumps({"status": "SELF_TEST_PASS"}, sort_keys=True))
    else:
        print(json.dumps(run_live(args.source_dir, args.output), sort_keys=True))


if __name__ == "__main__":
    main()

