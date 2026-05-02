from __future__ import annotations

import pandas as pd


COLUMN_ALIASES = {
    "日期": "time",
    "开盘": "open",
    "收盘": "close",
    "最高": "high",
    "最低": "low",
    "成交量": "volume",
    "成交额": "amount",
}


def normalize_daily_dataframe(frame: pd.DataFrame) -> pd.DataFrame:
    normalized = frame.rename(columns=COLUMN_ALIASES).copy()

    missing = [column for column in COLUMN_ALIASES.values() if column not in normalized.columns]
    if missing:
        raise ValueError(f"daily dataframe missing required columns: {missing}")

    normalized = normalized[["time", "open", "high", "low", "close", "volume", "amount"]]
    normalized["time"] = pd.to_datetime(normalized["time"])

    for column in ["open", "high", "low", "close", "volume", "amount"]:
        normalized[column] = pd.to_numeric(normalized[column], errors="coerce")

    normalized = normalized.dropna(subset=["time", "open", "high", "low", "close"])
    normalized = normalized.drop_duplicates(subset=["time"]).sort_values("time").reset_index(drop=True)
    return normalized

