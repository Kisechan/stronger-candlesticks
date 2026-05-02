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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: KlineChart(
                          bars: _session.bars,
                          revealedCount: _session.revealedCount,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      child: SectionSurface(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      _session.currentEquity.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                            ],
                          ),
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
                                ? _session.averageCost.toStringAsFixed(2)
                                : '—',
                          ),
                          InfoRow(
                            label: '待执行',
                            value: _session.pendingOrder == null
                                ? '无'
                                : _actionLabel(_session.pendingOrder!),
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
                          const SizedBox(height: 8),
                          SecondaryActionButton(
                            label: '清仓',
                            color: _session.canClear
                                ? AppColors.danger
                                : AppColors.textSecondary,
                            onPressed: _session.canClear
                                ? () => _showFeedback(_session.queueClear())
                                : null,
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
    TrainingAction.clear => '清仓',
  };
}
