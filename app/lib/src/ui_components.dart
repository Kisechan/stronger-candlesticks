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
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
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

class KlineChart extends StatefulWidget {
  const KlineChart({
    super.key,
    required this.bars,
    required this.revealedCount,
  });

  final List<SegmentBar> bars;
  final int revealedCount;

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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
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
                      ),
                    ),
                    if (selectedBar != null)
                      Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                          child: Text(
                            '${selectedBar.time}  O ${selectedBar.open.toStringAsFixed(2)}  H ${selectedBar.high.toStringAsFixed(2)}  L ${selectedBar.low.toStringAsFixed(2)}  C ${selectedBar.close.toStringAsFixed(2)}',
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
  });

  final List<SegmentBar> bars;
  final int viewStart;
  final int viewEnd;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 10.0;
    const rightPad = 44.0;
    const topPad = 32.0;
    const bottomPad = 24.0;

    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - rightPad,
      size.height - topPad - bottomPad,
    );
    final visibleCount = max(0, viewEnd - viewStart);
    if (visibleCount <= 0) {
      return;
    }

    final visibleBars = bars.sublist(viewStart, viewEnd);
    var minPrice = visibleBars.first.low;
    var maxPrice = visibleBars.first.high;
    for (final bar in visibleBars) {
      minPrice = min(minPrice, bar.low);
      maxPrice = max(maxPrice, bar.high);
      if (bar.ma5 != null) {
        minPrice = min(minPrice, bar.ma5!);
        maxPrice = max(maxPrice, bar.ma5!);
      }
      if (bar.ma10 != null) {
        minPrice = min(minPrice, bar.ma10!);
        maxPrice = max(maxPrice, bar.ma10!);
      }
      if (bar.ma20 != null) {
        minPrice = min(minPrice, bar.ma20!);
        maxPrice = max(maxPrice, bar.ma20!);
      }
    }

    final priceRange = maxPrice - minPrice;
    final safeRange = priceRange <= 0 ? 1.0 : priceRange * 1.06;
    final chartTop = maxPrice + safeRange * 0.02;
    final chartBottom = minPrice - safeRange * 0.04;

    final gridPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 0.8;
    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + chartRect.height * (i / 3);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final stride = chartRect.width / visibleCount;
    final candleWidth = max(4.0, stride * 0.54);
    final wickPaint = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final bodyPaint = Paint()..style = PaintingStyle.fill;

    double yForPrice(double price) {
      return chartRect.bottom -
          ((price - chartBottom) / (chartTop - chartBottom) * chartRect.height);
    }

    final ma5Path = Path();
    final ma10Path = Path();
    final ma20Path = Path();
    var ma5Started = false;
    var ma10Started = false;
    var ma20Started = false;

    for (var i = 0; i < visibleCount; i++) {
      final globalIndex = viewStart + i;
      final bar = bars[globalIndex];
      final centerX = chartRect.left + stride * i + stride / 2;
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

      if (bar.ma5 != null) {
        final point = Offset(centerX, yForPrice(bar.ma5!));
        if (!ma5Started) {
          ma5Path.moveTo(point.dx, point.dy);
          ma5Started = true;
        } else {
          ma5Path.lineTo(point.dx, point.dy);
        }
      }
      if (bar.ma10 != null) {
        final point = Offset(centerX, yForPrice(bar.ma10!));
        if (!ma10Started) {
          ma10Path.moveTo(point.dx, point.dy);
          ma10Started = true;
        } else {
          ma10Path.lineTo(point.dx, point.dy);
        }
      }
      if (bar.ma20 != null) {
        final point = Offset(centerX, yForPrice(bar.ma20!));
        if (!ma20Started) {
          ma20Path.moveTo(point.dx, point.dy);
          ma20Started = true;
        } else {
          ma20Path.lineTo(point.dx, point.dy);
        }
      }
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    linePaint.color = AppColors.ma5;
    canvas.drawPath(ma5Path, linePaint);
    linePaint.color = AppColors.ma10;
    canvas.drawPath(ma10Path, linePaint);
    linePaint.color = AppColors.ma20;
    canvas.drawPath(ma20Path, linePaint);

    final lastBar = bars[viewEnd - 1];
    final lastCloseY = yForPrice(lastBar.close);
    final lastLinePaint = Paint()
      ..color = AppColors.lineStrong
      ..strokeWidth = 0.9;
    canvas.drawLine(
      Offset(chartRect.left, lastCloseY),
      Offset(chartRect.right, lastCloseY),
      lastLinePaint,
    );

    if (selectedIndex != null &&
        selectedIndex! >= viewStart &&
        selectedIndex! < viewEnd) {
      final local = selectedIndex! - viewStart;
      final centerX = chartRect.left + stride * local + stride / 2;
      final bar = bars[selectedIndex!];
      final crossPaint = Paint()
        ..color = AppColors.lineStrong
        ..strokeWidth = 0.9;
      canvas.drawLine(
        Offset(centerX, chartRect.top),
        Offset(centerX, chartRect.bottom),
        crossPaint,
      );
      canvas.drawLine(
        Offset(chartRect.left, yForPrice(bar.close)),
        Offset(chartRect.right, yForPrice(bar.close)),
        crossPaint,
      );
    }

    _drawPriceLabel(canvas, chartRect.right + 8, chartRect.top, chartTop);
    _drawPriceLabel(
      canvas,
      chartRect.right + 8,
      chartRect.center.dy - 8,
      (chartTop + chartBottom) / 2,
    );
    _drawPriceLabel(
      canvas,
      chartRect.right + 8,
      chartRect.bottom - 16,
      chartBottom,
    );

    _drawBottomLabel(
      canvas,
      chartRect.left,
      chartRect.bottom + 4,
      bars[viewStart].time,
    );
    _drawBottomLabel(
      canvas,
      chartRect.center.dx - 20,
      chartRect.bottom + 4,
      bars[(viewStart + viewEnd - 1) ~/ 2].time,
    );
    _drawBottomLabel(
      canvas,
      chartRect.right - 50,
      chartRect.bottom + 4,
      bars[viewEnd - 1].time,
    );
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
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.line);
  }
}
