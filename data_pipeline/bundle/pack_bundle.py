from __future__ import annotations

import json
import shutil
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from data_pipeline.common import SegmentArtifact, compute_payload_hash, ensure_dir, write_json


def pack_bundle(
    *,
    output_dir: Path,
    build_dir: Path,
    bundle_config: dict[str, Any],
    stocks_payload: list[dict[str, Any]],
    segments: list[SegmentArtifact],
) -> dict[str, Any]:
    bundle_id = f"{bundle_config['bundle_id_prefix']}_{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}"
    staging_dir = build_dir / bundle_id
    if staging_dir.exists():
        shutil.rmtree(staging_dir)
    ensure_dir(staging_dir)

    segment_index = []
    for artifact in segments:
        target_path = staging_dir / artifact.metadata["path"]
        ensure_dir(target_path.parent)
        write_json(target_path, artifact.payload)
        segment_index.append(artifact.metadata)

    write_json(staging_dir / "stocks.json", stocks_payload)
    write_json(staging_dir / "segment_index.json", segment_index)

    # The hash intentionally excludes manifest.json to avoid a self-referential archive hash.
    payload_hash = compute_payload_hash(staging_dir)
    manifest = {
        "schemaVersion": 1,
        "bundleId": bundle_id,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "market": bundle_config["market"],
        "periods": bundle_config["periods"],
        "futureCompatiblePeriods": bundle_config["future_compatible_periods"],
        "symbolCount": len(stocks_payload),
        "segmentCount": len(segments),
        "segmentLength": bundle_config["training_bars"],
        "fields": bundle_config["fields"],
        "indicators": bundle_config["indicators"],
        "hash": {
            "algorithm": "sha256",
            "value": payload_hash,
        },
    }
    write_json(staging_dir / "manifest.json", manifest)

    ensure_dir(output_dir)
    archive_path = output_dir / f"{bundle_id}.ktpkg"
    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for file_path in sorted(path for path in staging_dir.rglob("*") if path.is_file()):
            archive.write(file_path, file_path.relative_to(staging_dir).as_posix())

    return {
        "bundleId": bundle_id,
        "archivePath": str(archive_path),
        "manifest": manifest,
        "stagingDir": str(staging_dir),
    }

