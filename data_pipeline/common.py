from __future__ import annotations

import csv
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pandas as pd
import yaml


STANDARD_FIELDS = ["time", "open", "high", "low", "close", "volume", "amount"]
INDICATOR_FIELDS = ["ma5", "ma10", "ma20", "macdDiff", "macdDea", "macdHist"]


@dataclass
class SegmentArtifact:
    metadata: dict[str, Any]
    payload: dict[str, Any]


def load_config(config_path: Path) -> dict[str, Any]:
    with config_path.open("r", encoding="utf-8") as handle:
        config = yaml.safe_load(handle) or {}

    base_dir = config_path.parent
    paths = config.setdefault("paths", {})
    for key, value in list(paths.items()):
        paths[key] = resolve_path(base_dir, value)

    return config


def resolve_path(base_dir: Path, raw_path: str) -> Path:
    path = Path(raw_path)
    if path.is_absolute():
        return path
    return (base_dir / path).resolve()


def ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def read_stock_pool(csv_path: Path) -> list[dict[str, str]]:
    with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return [dict(row) for row in reader if row.get("symbol")]


def normalize_cn_symbol(raw_symbol: str) -> str:
    digits = "".join(ch for ch in str(raw_symbol) if ch.isdigit())
    if len(digits) != 6:
        raise ValueError(f"symbol must resolve to 6 digits, got {raw_symbol!r}")
    return digits


def with_exchange_suffix(symbol: str) -> str:
    code = normalize_cn_symbol(symbol)
    if code.startswith(("600", "601", "603", "605", "688", "689", "900")):
        return f"{code}.SH"
    if code.startswith(("430", "830", "831", "832", "833", "834", "835", "836", "837", "838", "839", "870", "871", "872", "873", "874", "875", "876", "877", "878", "879")):
        return f"{code}.BJ"
    return f"{code}.SZ"


def exchange_from_symbol(symbol: str) -> str:
    return with_exchange_suffix(symbol).split(".")[-1]


def dataframe_to_bar_records(frame: pd.DataFrame) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for row in frame.to_dict(orient="records"):
        converted: dict[str, Any] = {}
        for key, value in row.items():
            if isinstance(value, pd.Timestamp):
                converted[key] = value.strftime("%Y-%m-%d")
            elif pd.isna(value):
                converted[key] = None
            elif isinstance(value, bool):
                converted[key] = value
            elif isinstance(value, int):
                converted[key] = value
            elif isinstance(value, float):
                converted[key] = round(value, 6)
            else:
                converted[key] = value
        records.append(converted)
    return records


def write_json(path: Path, payload: Any) -> None:
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)


def compute_payload_hash(bundle_dir: Path) -> str:
    digest = hashlib.sha256()
    for file_path in sorted(path for path in bundle_dir.rglob("*") if path.is_file() and path.name != "manifest.json"):
        relative_path = file_path.relative_to(bundle_dir).as_posix().encode("utf-8")
        digest.update(relative_path)
        digest.update(b"\0")
        digest.update(file_path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()

