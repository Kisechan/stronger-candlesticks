from __future__ import annotations

import pandas as pd


def apply_indicators(frame: pd.DataFrame) -> pd.DataFrame:
    enriched = frame.copy()

    for window in (5, 10, 20, 30, 60, 120):
        enriched[f"ma{window}"] = enriched["close"].rolling(window=window, min_periods=window).mean()

    ema12 = enriched["close"].ewm(span=12, adjust=False).mean()
    ema26 = enriched["close"].ewm(span=26, adjust=False).mean()
    enriched["macdDiff"] = ema12 - ema26
    enriched["macdDea"] = enriched["macdDiff"].ewm(span=9, adjust=False).mean()
    enriched["macdHist"] = (enriched["macdDiff"] - enriched["macdDea"]) * 2

    # The app expects fully-populated indicator windows, so early partial rows are removed.
    enriched = enriched.dropna(subset=["ma120"]).reset_index(drop=True)
    return enriched
