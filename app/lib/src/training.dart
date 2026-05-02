import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';

enum TrainingStatus { ready, running, completed, aborted }

class TrainingSessionController extends ChangeNotifier {
  TrainingSessionController({required this.seed, this.initialCash = 100000})
    : _revealedCount = seed.payload.contextBars,
      _status = TrainingStatus.ready,
      _startedAt = DateTime.now() {
    _cash = initialCash;
  }

  final TrainingSeed seed;
  final double initialCash;
  final DateTime _startedAt;
  final List<TrainingTrade> _trades = [];

  int _revealedCount;
  late double _cash;
  double _shares = 0;
  double _averageCost = 0;
  TrainingAction? _pendingOrder;
  TrainingStatus _status;

  List<SegmentBar> get bars => seed.payload.bars;
  int get revealedCount => _revealedCount;
  int get currentProgress => max(0, _revealedCount - seed.payload.contextBars);
  int get maxProgress => seed.payload.trainingBars;
  double get cash => _cash;
  double get shares => _shares;
  double get averageCost => _averageCost;
  TrainingAction? get pendingOrder => _pendingOrder;
  TrainingStatus get status => _status;
  List<TrainingTrade> get trades => List.unmodifiable(_trades);
  bool get isCompleted => _status == TrainingStatus.completed;
  bool get hasPosition => _shares > 0.000001;
  bool get canAdvance => _revealedCount < bars.length;
  bool get canBuy => canAdvance && !hasPosition && _pendingOrder == null;
  bool get canSell => canAdvance && hasPosition && _pendingOrder == null;
  bool get canClear => canSell;
  SegmentBar get currentBar => bars[_revealedCount - 1];
  double get currentEquity => _cash + _shares * currentBar.close;
  double get floatingReturnPct => initialCash == 0
      ? 0.0
      : ((currentEquity - initialCash) / initialCash) * 100;

  String queueBuy() {
    if (!canBuy) {
      return '当前不可买入';
    }
    _pendingOrder = TrainingAction.buy;
    _status = TrainingStatus.running;
    notifyListeners();
    return '已提交买入，将于下一根开盘成交';
  }

  String queueSell() {
    if (!canSell) {
      return '当前不可卖出';
    }
    _pendingOrder = TrainingAction.sell;
    notifyListeners();
    return '已提交卖出，将于下一根开盘成交';
  }

  String queueClear() {
    if (!canClear) {
      return '当前没有可清仓的持仓';
    }
    _pendingOrder = TrainingAction.clear;
    notifyListeners();
    return '已提交清仓，将于下一根开盘成交';
  }

  String advance() {
    if (!canAdvance) {
      return '本轮训练已结束';
    }

    final nextBar = bars[_revealedCount];
    String executionFeedback = '';
    if (_pendingOrder != null) {
      executionFeedback = _executePendingOrder(
        nextBar: nextBar,
        barIndex: _revealedCount,
      );
      _pendingOrder = null;
    }

    _revealedCount += 1;
    if (_revealedCount >= bars.length) {
      _status = TrainingStatus.completed;
    } else {
      _status = TrainingStatus.running;
    }
    notifyListeners();

    if (executionFeedback.isNotEmpty && isCompleted) {
      return '$executionFeedback，本轮训练结束';
    }
    if (executionFeedback.isNotEmpty) {
      return executionFeedback;
    }
    if (isCompleted) {
      return '已揭示最后一根 K 线';
    }
    return '已推进到下一根';
  }

  String _executePendingOrder({
    required SegmentBar nextBar,
    required int barIndex,
  }) {
    final executionPrice = nextBar.open;

    switch (_pendingOrder) {
      case TrainingAction.buy:
        final purchasedShares = executionPrice <= 0
            ? 0.0
            : _cash / executionPrice;
        _shares = purchasedShares;
        _cash = 0;
        _averageCost = executionPrice;
        _trades.add(
          TrainingTrade(
            action: TrainingAction.buy,
            barIndex: barIndex,
            time: nextBar.time,
            price: executionPrice,
            equityAfter: _shares * nextBar.close,
          ),
        );
        return '已按下一根开盘价买入';
      case TrainingAction.sell:
      case TrainingAction.clear:
        _cash += _shares * executionPrice;
        _shares = 0;
        _averageCost = 0;
        _trades.add(
          TrainingTrade(
            action: _pendingOrder!,
            barIndex: barIndex,
            time: nextBar.time,
            price: executionPrice,
            equityAfter: _cash,
          ),
        );
        return _pendingOrder == TrainingAction.clear
            ? '已按下一根开盘价清仓'
            : '已按下一根开盘价卖出';
      case null:
        return '';
    }
  }

  TrainingResult buildResult() {
    final buyCount = _trades
        .where((trade) => trade.action == TrainingAction.buy)
        .length;
    final sellCount = _trades
        .where((trade) => trade.action != TrainingAction.buy)
        .length;
    final returnPct = initialCash == 0
        ? 0.0
        : ((currentEquity - initialCash) / initialCash) * 100;
    final tradeCount = _trades.length;

    final summary = switch ((returnPct, tradeCount)) {
      (>= 5, <= 3) => '节奏稳，决策质量较高，训练结果偏强。',
      (> 0, >= 6) => '虽然盈利，但出手略频繁，可以再收敛一点。',
      (< 0, >= 6) => '本轮交易偏多且效果不佳，建议减少无效操作。',
      (< 0, _) => '本轮结果偏弱，建议更耐心等待确认信号。',
      _ => '完成了一轮标准训练，可以继续积累样本。',
    };

    return TrainingResult(
      sessionId: '${seed.entry.segmentId}_${_startedAt.millisecondsSinceEpoch}',
      segmentId: seed.entry.segmentId,
      symbol: seed.entry.symbol,
      startedAt: _startedAt,
      completedAt: DateTime.now(),
      initialCash: initialCash,
      finalEquity: currentEquity,
      totalReturnPct: returnPct,
      tradeCount: tradeCount,
      buyCount: buyCount,
      sellCount: sellCount,
      summary: summary,
      trades: List.unmodifiable(_trades),
    );
  }
}
