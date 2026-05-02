from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

import akshare as ak
import pandas as pd

from data_pipeline.common import normalize_cn_symbol


def fetch_daily_history(
    symbol: str,
    *,
    start_date: str,
    end_date: str | None = None,
    adjust: str = "qfq",
) -> pd.DataFrame:
    code = normalize_cn_symbol(symbol)
    effective_end_date = end_date or datetime.now().strftime("%Y%m%d")
    frame = ak.stock_zh_a_hist(
        symbol=code,
        period="daily",
        start_date=start_date,
        end_date=effective_end_date,
        adjust=adjust,
    )
    if frame.empty:
        raise ValueError(f"AKShare returned no rows for symbol={code}")
    return frame


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch CN A-share daily history with AKShare.")
    parser.add_argument("--symbol", required=True, help="6-digit stock code, for example 600519")
    parser.add_argument("--start-date", required=True, help="yyyymmdd")
    parser.add_argument("--end-date", default=None, help="yyyymmdd")
    parser.add_argument("--adjust", default="qfq", choices=["", "qfq", "hfq"], help="price adjustment mode")
    parser.add_argument("--output", type=Path, default=None, help="optional CSV output path")
    args = parser.parse_args()

    frame = fetch_daily_history(
        args.symbol,
        start_date=args.start_date,
        end_date=args.end_date,
        adjust=args.adjust,
    )

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        frame.to_csv(args.output, index=False, encoding="utf-8-sig")
    else:
        print(frame.to_csv(index=False))


if __name__ == "__main__":
    main()

