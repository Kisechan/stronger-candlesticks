from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import pandas as pd

from data_pipeline.bundle.pack_bundle import pack_bundle
from data_pipeline.bundle.verify_bundle import verify_bundle_archive
from data_pipeline.common import ensure_dir, exchange_from_symbol, load_config, read_stock_pool, with_exchange_suffix
from data_pipeline.fetch.fetch_daily import fetch_daily_history
from data_pipeline.process.indicators import apply_indicators
from data_pipeline.process.normalize import normalize_daily_dataframe
from data_pipeline.segment.segment_builder import build_segments


def build_bundle(config_path: Path) -> dict[str, Any]:
    config = load_config(config_path)
    bundle_config = config["bundle"]
    fetch_config = config["fetch"]
    paths = config["paths"]

    raw_dir = ensure_dir(paths["raw_dir"])
    processed_dir = ensure_dir(paths["processed_dir"])
    build_dir = ensure_dir(paths["build_dir"])
    output_dir = ensure_dir(paths["output_dir"])

    stock_pool = read_stock_pool(config_path.parent / "stock_pool.csv")
    if not stock_pool:
        raise ValueError("stock_pool.csv is empty")

    all_segments = []
    stocks_payload: list[dict[str, Any]] = []

    for stock in stock_pool:
        raw_symbol = stock["symbol"]
        symbol = with_exchange_suffix(raw_symbol)
        raw_cache_path = raw_dir / f"{symbol}.csv"
        processed_cache_path = processed_dir / f"{symbol}.csv"

        if fetch_config.get("use_cached_raw") and raw_cache_path.exists():
            raw_frame = pd.read_csv(raw_cache_path)
        else:
            raw_frame = fetch_daily_history(
                raw_symbol,
                start_date=fetch_config["start_date"],
                end_date=fetch_config.get("end_date"),
                adjust=fetch_config.get("adjust", "qfq"),
            )
            raw_frame.to_csv(raw_cache_path, index=False, encoding="utf-8-sig")

        normalized_frame = normalize_daily_dataframe(raw_frame)
        indicator_frame = apply_indicators(normalized_frame)
        indicator_frame.to_csv(processed_cache_path, index=False, encoding="utf-8-sig")

        segments = build_segments(
            indicator_frame,
            symbol=symbol,
            period="1d",
            context_bars=bundle_config["context_bars"],
            training_bars=bundle_config["training_bars"],
            stride=bundle_config.get("segment_stride", 1),
            max_segments=bundle_config.get("max_segments_per_symbol"),
        )

        if not segments:
            continue

        all_segments.extend(segments)
        stocks_payload.append(
            {
                "symbol": symbol,
                "code": raw_symbol,
                "exchange": exchange_from_symbol(raw_symbol),
                "name": stock.get("name") or "",
                "period": "1d",
                "barCount": int(len(indicator_frame)),
                "segmentCount": len(segments),
            }
        )

    if not all_segments:
        raise ValueError("no segments were generated; check stock pool or history window")

    pack_result = pack_bundle(
        output_dir=output_dir,
        build_dir=build_dir,
        bundle_config=bundle_config,
        stocks_payload=stocks_payload,
        segments=all_segments,
    )
    verify_result = verify_bundle_archive(Path(pack_result["archivePath"]))

    return {
        "bundle": pack_result,
        "verify": verify_result,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch daily history, build segments and pack a .ktpkg bundle.")
    default_config = Path(__file__).resolve().parent / "config.yaml"
    parser.add_argument("--config", type=Path, default=default_config, help="pipeline config path")
    args = parser.parse_args()

    result = build_bundle(args.config.resolve())
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
