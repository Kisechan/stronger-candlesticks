import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../models.dart';
import '../theme.dart';
import '../training.dart';
import '../ui_components.dart';
import 'result_page.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key, required this.controller, required this.seed});

  final AppController controller;
  final TrainingSeed seed;

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late final TrainingSessionController _session;
  final Set<MovingAverageLine> _movingAverages = {
    MovingAverageLine.ma5,
    MovingAverageLine.ma10,
    MovingAverageLine.ma20,
  };
  _SecondaryPaneMode _secondaryPaneMode = _SecondaryPaneMode.both;
  bool _showAccountPanel = false;
  String? _feedback;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _session = TrainingSessionController(seed: widget.seed);
    _session.addListener(_handleSessionChange);
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _session.removeListener(_handleSessionChange);
    _session.dispose();
    super.dispose();
  }

  void _handleSessionChange() {
    if (_session.isCompleted) {
      final result = _session.buildResult();
      widget.controller.recordResult(result).then((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (_) =>
                ResultPage(controller: widget.controller, result: result),
          ),
        );
      });
    }
  }

  void _showFeedback(String message) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedback = message;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _feedback = null;
      });
    });
  }

  Future<void> _confirmExit() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) {
        return CupertinoActionSheet(
          title: const Text('结束本次训练？'),
          message: const Text('当前进度不会继续保留。'),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('结束训练'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('继续训练'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockName = widget.seed.stock.name.isEmpty
        ? widget.seed.stock.symbol
        : widget.seed.stock.name;
    final returnColor = _session.floatingReturnPct >= 0
        ? AppColors.accent
        : AppColors.danger;
    final showVolume = switch (_secondaryPaneMode) {
      _SecondaryPaneMode.volume || _SecondaryPaneMode.both => true,
      _ => false,
    };
    final showMacd = switch (_secondaryPaneMode) {
      _SecondaryPaneMode.macd || _SecondaryPaneMode.both => true,
      _ => false,
    };

    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        return CupertinoPageScaffold(
          backgroundColor: AppColors.background,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            minimumSize: Size.zero,
                            onPressed: _confirmExit,
                            child: const Icon(
                              CupertinoIcons.xmark,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  stockName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${widget.seed.stock.symbol} · ${_session.currentProgress}/${_session.maxProgress}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 36),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: KlineChart(
                                bars: _session.bars,
                                revealedCount: _session.revealedCount,
                                movingAverages: _movingAverages,
                                showVolume: showVolume,
                                showMacd: showMacd,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '图表调节',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                CupertinoSlidingSegmentedControl<
                                  _SecondaryPaneMode
                                >(
                                  groupValue: _secondaryPaneMode,
                                  thumbColor: AppColors.surface,
                                  backgroundColor: AppColors.surfaceMuted,
                                  children: const {
                                    _SecondaryPaneMode.none: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: Text('主图'),
                                    ),
                                    _SecondaryPaneMode.volume: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: Text('VOL'),
                                    ),
                                    _SecondaryPaneMode.macd: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: Text('MACD'),
                                    ),
                                    _SecondaryPaneMode.both: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      child: Text('VOL+MACD'),
                                    ),
                                  },
                                  onValueChanged: (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    setState(() {
                                      _secondaryPaneMode = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...MovingAverageLine.values.map(
                                        (line) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: _IndicatorChip(
                                            label: line.label,
                                            active: _movingAverages.contains(
                                              line,
                                            ),
                                            color: line.color,
                                            onPressed: () {
                                              setState(() {
                                                if (_movingAverages.contains(
                                                  line,
                                                )) {
                                                  _movingAverages.remove(line);
                                                } else {
                                                  _movingAverages.add(line);
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: SectionSurface(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _showAccountPanel = !_showAccountPanel;
                              });
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '当前权益',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _session.currentEquity.toStringAsFixed(
                                          2,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${_session.floatingReturnPct >= 0 ? '+' : ''}${_session.floatingReturnPct.toStringAsFixed(2)}%',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                        color: returnColor,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _showAccountPanel ? '收起明细' : '展开明细',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _showAccountPanel
                                              ? CupertinoIcons.chevron_up
                                              : CupertinoIcons.chevron_down,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            alignment: Alignment.topCenter,
                            curve: Curves.easeOutCubic,
                            child: _showAccountPanel
                                ? Column(
                                    children: [
                                      const SizedBox(height: 2),
                                      InfoRow(
                                        label: '现金',
                                        value: _session.cash.toStringAsFixed(2),
                                      ),
                                      InfoRow(
                                        label: '持仓',
                                        value: _session.shares > 0
                                            ? _session.shares.toStringAsFixed(2)
                                            : '0',
                                      ),
                                      InfoRow(
                                        label: '持仓均价',
                                        value: _session.averageCost > 0
                                            ? _session.averageCost
                                                  .toStringAsFixed(2)
                                            : '—',
                                      ),
                                      InfoRow(
                                        label: '待执行',
                                        value: _session.pendingOrder == null
                                            ? '无'
                                            : _actionLabel(
                                                _session.pendingOrder!,
                                              ),
                                      ),
                                      InfoRow(
                                        label: '当前量能',
                                        value:
                                            '${(_session.currentBar.volume / 10000).toStringAsFixed(1)} 万',
                                      ),
                                      InfoRow(
                                        label: '当前换手',
                                        value:
                                            _session.currentBar.turnoverRate ==
                                                null
                                            ? '—'
                                            : '${_session.currentBar.turnoverRate!.toStringAsFixed(2)}%',
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: _session.canSell
                                      ? () =>
                                            _showFeedback(_session.queueSell())
                                      : null,
                                  child: _ActionTile(
                                    label: '卖出',
                                    color: AppColors.fall,
                                    enabled: _session.canSell,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: _session.canAdvance
                                      ? () => _showFeedback(_session.advance())
                                      : null,
                                  child: _ActionTile(
                                    label: '下一根',
                                    color: AppColors.accent,
                                    enabled: _session.canAdvance,
                                    prominent: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: _session.canBuy
                                      ? () => _showFeedback(_session.queueBuy())
                                      : null,
                                  child: _ActionTile(
                                    label: '买入',
                                    color: AppColors.rise,
                                    enabled: _session.canBuy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_feedback != null)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 144,
                    child: Center(child: FeedbackPill(text: _feedback!)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.14)
              : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? color : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

enum _SecondaryPaneMode { none, volume, macd, both }

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.color,
    required this.enabled,
    this.prominent = false,
  });

  final String label;
  final Color color;
  final bool enabled;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final background = enabled ? color : AppColors.surfaceMuted;
    final textColor = enabled ? CupertinoColors.white : AppColors.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: prominent ? 56 : 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _actionLabel(TrainingAction action) {
  return switch (action) {
    TrainingAction.buy => '买入',
    TrainingAction.sell => '卖出',
  };
}
