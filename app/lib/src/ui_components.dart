import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

import 'models.dart';
import 'theme.dart';

class SectionSurface extends StatelessWidget {
  const SectionSurface({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _withHairlines(children),
      ),
    );
  }

  List<Widget> _withHairlines(List<Widget> items) {
    final output = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        output.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: _Hairline(),
          ),
        );
      }
      output.add(items[i]);
    }
    return output;
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.multiline = true,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            softWrap: multiline,
            maxLines: multiline ? null : 1,
            overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? AppColors.accent : AppColors.surfaceMuted;
    final textColor = enabled ? AppColors.surface : AppColors.textSecondary;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    super.key,
    required this.label,
    this.color = AppColors.textPrimary,
    this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: BorderRadius.circular(12),
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ThinProgressBar extends StatelessWidget {
  const ThinProgressBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 5,
        color: AppColors.surfaceMuted,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0, 1),
            child: Container(color: AppColors.accent),
          ),
        ),
      ),
    );
  }
}

class FeedbackPill extends StatelessWidget {
  const FeedbackPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE1C1C1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          text,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

enum MovingAverageLine { ma5, ma10, ma20, ma30, ma60, ma120 }

extension MovingAverageLineX on MovingAverageLine {
  String get label => switch (this) {
    MovingAverageLine.ma5 => 'MA5',
    MovingAverageLine.ma10 => 'MA10',
    MovingAverageLine.ma20 => 'MA20',
    MovingAverageLine.ma30 => 'MA30',
    MovingAverageLine.ma60 => 'MA60',
    MovingAverageLine.ma120 => 'MA120',
  };

  Color get color => switch (this) {
    MovingAverageLine.ma5 => AppColors.ma5,
    MovingAverageLine.ma10 => AppColors.ma10,
    MovingAverageLine.ma20 => AppColors.ma20,
    MovingAverageLine.ma30 => AppColors.ma30,
    MovingAverageLine.ma60 => AppColors.ma60,
    MovingAverageLine.ma120 => AppColors.ma120,
  };
}

class KlineChart extends StatefulWidget {
  const KlineChart({
    super.key,
    required this.bars,
    required this.revealedCount,
    required this.movingAverages,
    this.showVolume = true,
    this.showMacd = true,
  });

  final List<SegmentBar> bars;
  final int revealedCount;
  final Set<MovingAverageLine> movingAverages;
  final bool showVolume;
  final bool showMacd;

  @override
  State<KlineChart> createState() => _KlineChartState();
}

class _KlineChartState extends State<KlineChart> {
  static const _windowSize = 36;
  int _viewStart = 0;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _syncViewport(forceTail: true);
  }

  @override
  void didUpdateWidget(covariant KlineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncViewport(forceTail: widget.revealedCount > oldWidget.revealedCount);
    if (_selectedIndex != null && _selectedIndex! >= widget.revealedCount) {
      _selectedIndex = widget.revealedCount - 1;
    }
  }

  void _syncViewport({required bool forceTail}) {
    final maxStart = max(0, widget.revealedCount - _windowSize);
    if (forceTail) {
      _viewStart = maxStart;
      return;
    }
    _viewStart = _viewStart.clamp(0, maxStart);
  }

  void _handlePan(DragUpdateDetails details) {
    final delta = (details.delta.dx / 16).round();
    if (delta == 0) {
      return;
    }
    final maxStart = max(0, widget.revealedCount - _windowSize);
    setState(() {
      _viewStart = (_viewStart - delta).clamp(0, maxStart);
    });
  }

  void _updateSelection(Offset localPosition, double width) {
    final visibleCount = min(_windowSize, widget.revealedCount - _viewStart);
    if (visibleCount <= 0) {
      return;
    }
    final candleStride = width / visibleCount;
    final index = _viewStart + (localPosition.dx / candleStride).floor();
    setState(() {
      _selectedIndex = index.clamp(_viewStart, widget.revealedCount - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final end = min(widget.revealedCount, _viewStart + _windowSize);
    final selectedBar = _selectedIndex == null
        ? null
        : widget.bars[_selectedIndex!];

    return LayoutBuilder(
      builder: (context, constraints) {
        return RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.chartBackground, AppColors.surface],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 20,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onDoubleTap: () {
                  setState(() {
                    _selectedIndex = null;
                    _syncViewport(forceTail: true);
                  });
                },
                onHorizontalDragUpdate: _handlePan,
                onLongPressStart: (details) => _updateSelection(
                  details.localPosition,
                  constraints.maxWidth,
                ),
                onLongPressMoveUpdate: (details) => _updateSelection(
                  details.localPosition,
                  constraints.maxWidth,
                ),
                onLongPressEnd: (_) => setState(() => _selectedIndex = null),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _KlinePainter(
                        bars: widget.bars,
                        viewStart: _viewStart,
                        viewEnd: end,
                        selectedIndex: _selectedIndex,
                        movingAverages: widget.movingAverages,
                        showVolume: widget.showVolume,
                        showMacd: widget.showMacd,
                      ),
                    ),
                    if (selectedBar != null)
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Text(
                            '${selectedBar.time}  O ${selectedBar.open.toStringAsFixed(2)}  H ${selectedBar.high.toStringAsFixed(2)}  L ${selectedBar.low.toStringAsFixed(2)}  C ${selectedBar.close.toStringAsFixed(2)}  V ${(selectedBar.volume / 10000).toStringAsFixed(1)}万  换手 ${selectedBar.turnoverRate?.toStringAsFixed(2) ?? '--'}%',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KlinePainter extends CustomPainter {
  const _KlinePainter({
    required this.bars,
    required this.viewStart,
    required this.viewEnd,
    required this.selectedIndex,
    required this.movingAverages,
    required this.showVolume,
    required this.showMacd,
  });

  final List<SegmentBar> bars;
  final int viewStart;
  final int viewEnd;
  final int? selectedIndex;
  final Set<MovingAverageLine> movingAverages;
  final bool showVolume;
  final bool showMacd;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 10.0;
    const rightPad = 44.0;
    const topPad = 32.0;
    const bottomPad = 24.0;
    const paneGap = 10.0;

    final drawableHeight = size.height - topPad - bottomPad;
    final volumeHeight = showVolume ? drawableHeight * 0.18 : 0.0;
    final macdHeight = showMacd ? drawableHeight * 0.2 : 0.0;
    final gapCount = (showVolume ? 1 : 0) + (showMacd ? 1 : 0);
    final priceHeight =
        drawableHeight - volumeHeight - macdHeight - gapCount * paneGap;

    final priceRect = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - rightPad,
      priceHeight,
    );
    final volumeRect = showVolume
        ? Rect.fromLTWH(
            leftPad,
            priceRect.bottom + paneGap,
            priceRect.width,
            volumeHeight,
          )
        : Rect.zero;
    final macdRect = showMacd
        ? Rect.fromLTWH(
            leftPad,
            (showVolume ? volumeRect.bottom : priceRect.bottom) + paneGap,
            priceRect.width,
            macdHeight,
          )
        : Rect.zero;

    final visibleCount = max(0, viewEnd - viewStart);
    if (visibleCount <= 0) {
      return;
    }

    final visibleBars = bars.sublist(viewStart, viewEnd);
    var minPrice = visibleBars.first.low;
    var maxPrice = visibleBars.first.high;
    var maxVolume = 0.0;
    var maxMacdAbs = 0.0;

    for (final bar in visibleBars) {
      minPrice = min(minPrice, bar.low);
      maxPrice = max(maxPrice, bar.high);
      maxVolume = max(maxVolume, bar.volume);
      maxMacdAbs = max(
        maxMacdAbs,
        max(
          (bar.macdHist ?? 0).abs(),
          max((bar.macdDiff ?? 0).abs(), (bar.macdDea ?? 0).abs()),
        ),
      );
      for (final average in movingAverages) {
        final value = _movingAverageValue(bar, average);
        if (value != null) {
          minPrice = min(minPrice, value);
          maxPrice = max(maxPrice, value);
        }
      }
    }

    final priceRange = maxPrice - minPrice;
    final safeRange = priceRange <= 0 ? 1.0 : priceRange * 1.06;
    final chartTop = maxPrice + safeRange * 0.02;
    final chartBottom = minPrice - safeRange * 0.04;
    final safeMacdAbs = maxMacdAbs <= 0 ? 1.0 : maxMacdAbs * 1.12;

    final shadePaint = Paint()..color = AppColors.chartShade;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(22),
      ),
      shadePaint,
    );

    final gridPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 0.8;
    for (var i = 0; i < 4; i++) {
      final y = priceRect.top + priceRect.height * (i / 3);
      canvas.drawLine(
        Offset(priceRect.left, y),
        Offset(priceRect.right, y),
        gridPaint,
      );
    }
    if (showVolume) {
      canvas.drawLine(
        Offset(volumeRect.left, volumeRect.top),
        Offset(volumeRect.right, volumeRect.top),
        gridPaint,
      );
    }
    if (showMacd) {
      canvas.drawLine(
        Offset(macdRect.left, macdRect.top),
        Offset(macdRect.right, macdRect.top),
        gridPaint,
      );
      canvas.drawLine(
        Offset(macdRect.left, macdRect.center.dy),
        Offset(macdRect.right, macdRect.center.dy),
        gridPaint,
      );
    }

    final stride = priceRect.width / visibleCount;
    final candleWidth = max(4.0, stride * 0.54);

    double yForPrice(double price) {
      return priceRect.bottom -
          ((price - chartBottom) / (chartTop - chartBottom) * priceRect.height);
    }

    double yForMacd(double value) {
      return macdRect.center.dy -
          (value / safeMacdAbs) * (macdRect.height * 0.42);
    }

    final wickPaint = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final bodyPaint = Paint()..style = PaintingStyle.fill;
    final volumePaint = Paint()..style = PaintingStyle.fill;
    final histogramPaint = Paint()..style = PaintingStyle.fill;
    final averagePaths = <MovingAverageLine, Path>{
      for (final average in movingAverages) average: Path(),
    };
    final averageStarted = <MovingAverageLine, bool>{
      for (final average in movingAverages) average: false,
    };
    final diffPath = Path();
    final deaPath = Path();
    var diffStarted = false;
    var deaStarted = false;

    for (var i = 0; i < visibleCount; i++) {
      final globalIndex = viewStart + i;
      final bar = bars[globalIndex];
      final centerX = priceRect.left + stride * i + stride / 2;
      final openY = yForPrice(bar.open);
      final closeY = yForPrice(bar.close);
      final highY = yForPrice(bar.high);
      final lowY = yForPrice(bar.low);
      final isRise = bar.close >= bar.open;

      wickPaint.color = isRise ? AppColors.rise : AppColors.fall;
      bodyPaint.color = isRise ? AppColors.rise : AppColors.fall;

      canvas.drawLine(Offset(centerX, highY), Offset(centerX, lowY), wickPaint);
      final bodyTop = min(openY, closeY);
      final bodyBottom = max(openY, closeY);
      final bodyRect = Rect.fromCenter(
        center: Offset(centerX, (bodyTop + bodyBottom) / 2),
        width: candleWidth,
        height: max(1.8, bodyBottom - bodyTop),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(1.4)),
        bodyPaint,
      );

      for (final average in movingAverages) {
        final value = _movingAverageValue(bar, average);
        if (value == null) {
          continue;
        }
        final point = Offset(centerX, yForPrice(value));
        if (!(averageStarted[average] ?? false)) {
          averagePaths[average]!.moveTo(point.dx, point.dy);
          averageStarted[average] = true;
        } else {
          averagePaths[average]!.lineTo(point.dx, point.dy);
        }
      }

      if (showVolume) {
        final ratio = maxVolume <= 0 ? 0.0 : bar.volume / maxVolume;
        final volumeTop = volumeRect.bottom - volumeRect.height * ratio;
        volumePaint.color = (isRise ? AppColors.rise : AppColors.fall)
            .withValues(alpha: 0.34);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              centerX - candleWidth / 2,
              volumeTop,
              centerX + candleWidth / 2,
              volumeRect.bottom,
            ),
            const Radius.circular(1.2),
          ),
          volumePaint,
        );
      }

      if (showMacd) {
        final hist = bar.macdHist ?? 0;
        final zeroY = yForMacd(0);
        final histY = yForMacd(hist);
        histogramPaint.color = (hist >= 0 ? AppColors.rise : AppColors.fall)
            .withValues(alpha: 0.58);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              centerX - candleWidth / 2,
              min(zeroY, histY),
              centerX + candleWidth / 2,
              max(zeroY, histY),
            ),
            const Radius.circular(1.0),
          ),
          histogramPaint,
        );

        if (bar.macdDiff case final diff?) {
          final point = Offset(centerX, yForMacd(diff));
          if (!diffStarted) {
            diffPath.moveTo(point.dx, point.dy);
            diffStarted = true;
          } else {
            diffPath.lineTo(point.dx, point.dy);
          }
        }
        if (bar.macdDea case final dea?) {
          final point = Offset(centerX, yForMacd(dea));
          if (!deaStarted) {
            deaPath.moveTo(point.dx, point.dy);
            deaStarted = true;
          } else {
            deaPath.lineTo(point.dx, point.dy);
          }
        }
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    for (final average in movingAverages) {
      linePaint.color = average.color;
      canvas.drawPath(averagePaths[average]!, linePaint);
    }
    if (showMacd) {
      linePaint.color = AppColors.macdDiff;
      canvas.drawPath(diffPath, linePaint);
      linePaint.color = AppColors.macdDea;
      canvas.drawPath(deaPath, linePaint);
    }

    var legendX = priceRect.left + 8;
    for (final average in movingAverages) {
      legendX = _drawLegendLabel(
        canvas,
        legendX,
        10,
        average.label,
        average.color,
      );
    }
    if (showVolume) {
      _drawSectionLabel(canvas, priceRect.left + 6, volumeRect.top + 4, 'VOL');
    }
    if (showMacd) {
      _drawSectionLabel(canvas, priceRect.left + 6, macdRect.top + 4, 'MACD');
    }

    final lastBar = bars[viewEnd - 1];
    final lastCloseY = yForPrice(lastBar.close);
    final lastLinePaint = Paint()
      ..color = AppColors.lineStrong
      ..strokeWidth = 0.9;
    canvas.drawLine(
      Offset(priceRect.left, lastCloseY),
      Offset(priceRect.right, lastCloseY),
      lastLinePaint,
    );

    if (selectedIndex != null &&
        selectedIndex! >= viewStart &&
        selectedIndex! < viewEnd) {
      final local = selectedIndex! - viewStart;
      final centerX = priceRect.left + stride * local + stride / 2;
      final bar = bars[selectedIndex!];
      final crossPaint = Paint()
        ..color = AppColors.lineStrong
        ..strokeWidth = 0.9;
      final crossBottom = showMacd
          ? macdRect.bottom
          : (showVolume ? volumeRect.bottom : priceRect.bottom);
      canvas.drawLine(
        Offset(centerX, priceRect.top),
        Offset(centerX, crossBottom),
        crossPaint,
      );
      canvas.drawLine(
        Offset(priceRect.left, yForPrice(bar.close)),
        Offset(priceRect.right, yForPrice(bar.close)),
        crossPaint,
      );
    }

    _drawPriceLabel(canvas, priceRect.right + 8, priceRect.top, chartTop);
    _drawPriceLabel(
      canvas,
      priceRect.right + 8,
      priceRect.center.dy - 8,
      (chartTop + chartBottom) / 2,
    );
    _drawPriceLabel(
      canvas,
      priceRect.right + 8,
      priceRect.bottom - 16,
      chartBottom,
    );

    final labelY =
        (showMacd
            ? macdRect.bottom
            : (showVolume ? volumeRect.bottom : priceRect.bottom)) +
        4;
    _drawBottomLabel(canvas, priceRect.left, labelY, bars[viewStart].time);
    _drawBottomLabel(
      canvas,
      priceRect.center.dx - 20,
      labelY,
      bars[(viewStart + viewEnd - 1) ~/ 2].time,
    );
    _drawBottomLabel(
      canvas,
      priceRect.right - 50,
      labelY,
      bars[viewEnd - 1].time,
    );
  }

  double? _movingAverageValue(SegmentBar bar, MovingAverageLine average) {
    return switch (average) {
      MovingAverageLine.ma5 => bar.ma5,
      MovingAverageLine.ma10 => bar.ma10,
      MovingAverageLine.ma20 => bar.ma20,
      MovingAverageLine.ma30 => bar.ma30,
      MovingAverageLine.ma60 => bar.ma60,
      MovingAverageLine.ma120 => bar.ma120,
    };
  }

  double _drawLegendLabel(
    Canvas canvas,
    double x,
    double y,
    String text,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
    return x + painter.width + 10;
  }

  void _drawSectionLabel(Canvas canvas, double x, double y, String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  void _drawPriceLabel(Canvas canvas, double x, double y, double price) {
    final painter = TextPainter(
      text: TextSpan(
        text: price.toStringAsFixed(2),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  void _drawBottomLabel(Canvas canvas, double x, double y, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 90);
    painter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _KlinePainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.viewStart != viewStart ||
        oldDelegate.viewEnd != viewEnd ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.showVolume != showVolume ||
        oldDelegate.showMacd != showMacd ||
        oldDelegate.movingAverages.length != movingAverages.length ||
        !oldDelegate.movingAverages.containsAll(movingAverages);
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.line);
  }
}
