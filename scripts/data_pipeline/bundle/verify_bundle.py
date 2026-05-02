from __future__ import annotations

import argparse
import json
import tempfile
import zipfile
from pathlib import Path
from typing import Any

from common import compute_payload_hash


REQUIRED_FILES = {"manifest.json", "stocks.json", "segment_index.json"}


def verify_bundle_archive(bundle_path: Path) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="ktpkg_verify_") as temp_dir:
        extracted_dir = Path(temp_dir)
        with zipfile.ZipFile(bundle_path, "r") as archive:
            archive.extractall(extracted_dir)

        present_root_files = {path.name for path in extracted_dir.iterdir() if path.is_file()}
        missing_root_files = REQUIRED_FILES - present_root_files
        if missing_root_files:
            raise ValueError(f"bundle missing required files: {sorted(missing_root_files)}")

        manifest = json.loads((extracted_dir / "manifest.json").read_text(encoding="utf-8"))
        stocks = json.loads((extracted_dir / "stocks.json").read_text(encoding="utf-8"))
        segment_index = json.loads((extracted_dir / "segment_index.json").read_text(encoding="utf-8"))

        if manifest["symbolCount"] != len(stocks):
            raise ValueError("manifest symbolCount does not match stocks.json")
        if manifest["segmentCount"] != len(segment_index):
            raise ValueError("manifest segmentCount does not match segment_index.json")

        computed_hash = compute_payload_hash(extracted_dir)
        if manifest["hash"]["value"] != computed_hash:
            raise ValueError("bundle payload hash mismatch")

        total_bars = None
        for segment_meta in segment_index:
            segment_path = extracted_dir / segment_meta["path"]
            if not segment_path.exists():
                raise ValueError(f"segment file missing: {segment_meta['path']}")

            segment_payload = json.loads(segment_path.read_text(encoding="utf-8"))
            expected_bars = segment_meta["contextBars"] + segment_meta["trainingBars"]
            if total_bars is None:
                total_bars = expected_bars
            if len(segment_payload.get("bars", [])) != expected_bars:
                raise ValueError(f"segment bar count mismatch: {segment_meta['segmentId']}")
            if segment_payload.get("segmentId") != segment_meta["segmentId"]:
                raise ValueError(f"segment id mismatch: {segment_meta['segmentId']}")

        return {
            "bundleId": manifest["bundleId"],
            "symbolCount": manifest["symbolCount"],
            "segmentCount": manifest["segmentCount"],
            "segmentBars": total_bars or 0,
            "archive": str(bundle_path),
            "hash": computed_hash,
        }


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify a generated .ktpkg bundle.")
    parser.add_argument("bundle_path", type=Path, help="path to .ktpkg archive")
    args = parser.parse_args()

    result = verify_bundle_archive(args.bundle_path)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

