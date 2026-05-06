from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

import akshare as ak
import pandas as pd


def with_exchange_suffix(symbol: str) -> str:
    code = "".join(ch for ch in str(symbol) if ch.isdigit()).zfill(6)
    if code.startswith(("600", "601", "603", "605", "688", "689", "900")):
        return f"{code}.SH"
    if code.startswith(
        (
            "430",
            "830",
            "831",
            "832",
            "833",
            "834",
            "835",
            "836",
            "837",
            "838",
            "839",
            "870",
            "871",
            "872",
            "873",
            "874",
            "875",
            "876",
            "877",
            "878",
            "879",
        )
    ):
        return f"{code}.BJ"
    return f"{code}.SZ"


def build_hs300_stock_pool() -> pd.DataFrame:
    frame = ak.index_stock_cons_csindex(symbol="000300")
    if frame.empty:
        raise ValueError("failed to fetch CSI 300 constituents")

    renamed = frame.rename(
        columns={
            "成分券代码": "symbol",
            "成分券名称": "name",
        }
    )
    stock_pool = renamed[["symbol", "name"]].copy()
    stock_pool["symbol"] = stock_pool["symbol"].astype(str).str.zfill(6)
    stock_pool["full_code"] = stock_pool["symbol"].map(with_exchange_suffix)
    stock_pool = stock_pool.drop_duplicates(subset=["symbol"]).sort_values(
        by="symbol"
    ).reset_index(drop=True)
    return stock_pool[["symbol", "full_code", "name"]]


def estimate_segment_count(
    raw_bar_count: int,
    *,
    context_bars: int,
    training_bars: int,
    stride: int,
    indicator_warmup: int = 119,
) -> int:
    processed_bar_count = max(0, raw_bar_count - indicator_warmup)
    total_bars = context_bars + training_bars
    if processed_bar_count < total_bars:
        return 0
    return ((processed_bar_count - total_bars) // stride) + 1


def filter_by_min_segments(
    stock_pool: pd.DataFrame,
    *,
    min_segments: int,
    start_date: str,
    context_bars: int,
    training_bars: int,
    stride: int,
) -> pd.DataFrame:
    selected_rows: list[dict[str, str]] = []
    end_date = datetime.now().strftime("%Y%m%d")

    for row in stock_pool.to_dict(orient="records"):
        frame = ak.stock_zh_a_hist(
            symbol=row["symbol"],
            period="daily",
            start_date=start_date,
            end_date=end_date,
            adjust="qfq",
        )
        segment_count = estimate_segment_count(
            len(frame),
            context_bars=context_bars,
            training_bars=training_bars,
            stride=stride,
        )
        if segment_count >= min_segments:
            selected_rows.append(
                {
                    "symbol": row["symbol"],
                    "full_code": row["full_code"],
                    "name": row["name"],
                    "estimated_segments": str(segment_count),
                }
            )

    return pd.DataFrame(selected_rows)


def write_stock_pool(
    csv_path: Path,
    *,
    min_segments: int,
    start_date: str,
    context_bars: int,
    training_bars: int,
    stride: int,
) -> pd.DataFrame:
    stock_pool = build_hs300_stock_pool()
    stock_pool = filter_by_min_segments(
        stock_pool,
        min_segments=min_segments,
        start_date=start_date,
        context_bars=context_bars,
        training_bars=training_bars,
        stride=stride,
    )
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    stock_pool.to_csv(csv_path, index=False, encoding="utf-8-sig")
    return stock_pool


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Write the latest CSI 300 constituents into stock_pool.csv."
    )
    default_output = Path(__file__).resolve().parent / "stock_pool.csv"
    parser.add_argument(
        "--output",
        type=Path,
        default=default_output,
        help="target CSV path",
    )
    parser.add_argument("--start-date", default="20180101", help="daily history start date")
    parser.add_argument("--min-segments", type=int, default=10, help="minimum estimated segment count per stock")
    parser.add_argument("--context-bars", type=int, default=20, help="reference bars per segment")
    parser.add_argument("--training-bars", type=int, default=30, help="training bars per segment")
    parser.add_argument("--stride", type=int, default=5, help="segment stride")
    args = parser.parse_args()

    stock_pool = write_stock_pool(
        args.output.resolve(),
        min_segments=args.min_segments,
        start_date=args.start_date,
        context_bars=args.context_bars,
        training_bars=args.training_bars,
        stride=args.stride,
    )
    print(
        f"wrote {len(stock_pool)} rows to {args.output.resolve()}"
    )
    print(stock_pool.head(10).to_string(index=False))


if __name__ == "__main__":
    main()
