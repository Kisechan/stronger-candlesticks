from __future__ import annotations

from statistics import mean
from typing import Any

import pandas as pd

from data_pipeline.common import SegmentArtifact, dataframe_to_bar_records


def build_segments(
    frame: pd.DataFrame,
    *,
    symbol: str,
    period: str,
    context_bars: int,
    training_bars: int,
    stride: int = 1,
    max_segments: int | None = None,
) -> list[SegmentArtifact]:
    total_bars = context_bars + training_bars
    if len(frame) < total_bars:
        return []

    artifacts: list[SegmentArtifact] = []
    for start_index in range(0, len(frame) - total_bars + 1, stride):
        window = frame.iloc[start_index : start_index + total_bars].reset_index(drop=True)
        bars = dataframe_to_bar_records(window)
        context_window = bars[:context_bars]
        training_window = bars[context_bars:]
        segment_end = bars[-1]["time"].replace("-", "")
        segment_id = f"{symbol.replace('.', '_')}_{period}_{start_index:05d}_{segment_end}"
        relative_path = f"segments/daily/{symbol}/{segment_id}.json"

        start_close = float(bars[context_bars - 1]["close"])
        end_close = float(bars[-1]["close"])
        return_pct = ((end_close - start_close) / start_close) * 100 if start_close else 0.0
        context_avg_volume = _safe_mean([float(bar["volume"]) for bar in context_window])
        training_avg_volume = _safe_mean([float(bar["volume"]) for bar in training_window])
        context_avg_turnover = _safe_mean(
            [
                float(bar["turnoverRate"]) if bar.get("turnoverRate") is not None else None
                for bar in context_window
            ]
        )
        training_avg_turnover = _safe_mean(
            [
                float(bar["turnoverRate"]) if bar.get("turnoverRate") is not None else None
                for bar in training_window
            ]
        )
        context_close_returns = [
            (
                ((float(context_window[index]["close"]) - float(context_window[index - 1]["close"]))
                 / float(context_window[index - 1]["close"]))
                * 100
            )
            for index in range(1, len(context_window))
            if float(context_window[index - 1]["close"]) != 0
        ]
        context_volatility = _safe_mean([abs(value) for value in context_close_returns])
        breakout_high = max(float(bar["high"]) for bar in context_window)
        breakdown_low = min(float(bar["low"]) for bar in context_window)

        metadata: dict[str, Any] = {
            "segmentId": segment_id,
            "symbol": symbol,
            "period": period,
            "path": relative_path,
            "contextBars": context_bars,
            "trainingBars": training_bars,
            "tags": [],
            "features": {
                "startTime": bars[0]["time"],
                "decisionTime": bars[context_bars - 1]["time"],
                "endTime": bars[-1]["time"],
                "startClose": round(start_close, 6),
                "endClose": round(end_close, 6),
                "returnPct": round(return_pct, 6),
                "contextHigh": round(breakout_high, 6),
                "contextLow": round(breakdown_low, 6),
                "contextAvgVolume": round(context_avg_volume, 6) if context_avg_volume is not None else None,
                "trainingAvgVolume": round(training_avg_volume, 6) if training_avg_volume is not None else None,
                "volumeDeltaPct": (
                    round(_safe_pct_change(context_avg_volume, training_avg_volume), 6)
                    if _safe_pct_change(context_avg_volume, training_avg_volume) is not None
                    else None
                ),
                "contextAvgTurnoverRate": (
                    round(context_avg_turnover, 6) if context_avg_turnover is not None else None
                ),
                "trainingAvgTurnoverRate": (
                    round(training_avg_turnover, 6) if training_avg_turnover is not None else None
                ),
                "turnoverDeltaPct": (
                    round(_safe_pct_change(context_avg_turnover, training_avg_turnover), 6)
                    if _safe_pct_change(context_avg_turnover, training_avg_turnover) is not None
                    else None
                ),
                "contextVolatilityPct": (
                    round(context_volatility, 6) if context_volatility is not None else None
                ),
                "decisionMacdDiff": round(float(bars[context_bars - 1]["macdDiff"]), 6),
                "decisionMacdDea": round(float(bars[context_bars - 1]["macdDea"]), 6),
                "decisionMacdHist": round(float(bars[context_bars - 1]["macdHist"]), 6),
                "decisionMa5GapPct": (
                    round(
                        _safe_pct_change(
                            float(bars[context_bars - 1]["ma5"]),
                            float(bars[context_bars - 1]["close"]),
                        ),
                        6,
                    )
                    if bars[context_bars - 1].get("ma5") is not None
                    else None
                ),
                "decisionMa20GapPct": (
                    round(
                        _safe_pct_change(
                            float(bars[context_bars - 1]["ma20"]),
                            float(bars[context_bars - 1]["close"]),
                        ),
                        6,
                    )
                    if bars[context_bars - 1].get("ma20") is not None
                    else None
                ),
            },
        }
        payload = {
            "segmentId": segment_id,
            "symbol": symbol,
            "period": period,
            "contextBars": context_bars,
            "trainingBars": training_bars,
            "bars": bars,
        }
        artifacts.append(SegmentArtifact(metadata=metadata, payload=payload))

        if max_segments is not None and len(artifacts) >= max_segments:
            break

    return artifacts


def _safe_mean(values: list[float | None]) -> float | None:
    filtered = [value for value in values if value is not None]
    if not filtered:
        return None
    return float(mean(filtered))


def _safe_pct_change(base: float | None, current: float | None) -> float | None:
    if base in (None, 0) or current is None:
        return None
    return ((current - base) / base) * 100
