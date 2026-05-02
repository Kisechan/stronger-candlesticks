from __future__ import annotations

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
        segment_end = bars[-1]["time"].replace("-", "")
        segment_id = f"{symbol.replace('.', '_')}_{period}_{start_index:05d}_{segment_end}"
        relative_path = f"segments/daily/{symbol}/{segment_id}.json"

        start_close = float(bars[context_bars - 1]["close"])
        end_close = float(bars[-1]["close"])
        return_pct = ((end_close - start_close) / start_close) * 100 if start_close else 0.0

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

