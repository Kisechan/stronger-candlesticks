import 'dart:convert';

class BundleManifest {
  const BundleManifest({
    required this.schemaVersion,
    required this.bundleId,
    required this.createdAt,
    required this.market,
    required this.periods,
    required this.futureCompatiblePeriods,
    required this.symbolCount,
    required this.segmentCount,
    required this.segmentLength,
    required this.fields,
    required this.indicators,
    required this.hashAlgorithm,
    required this.hashValue,
  });

  final int schemaVersion;
  final String bundleId;
  final DateTime createdAt;
  final String market;
  final List<String> periods;
  final List<String> futureCompatiblePeriods;
  final int symbolCount;
  final int segmentCount;
  final int segmentLength;
  final List<String> fields;
  final List<String> indicators;
  final String hashAlgorithm;
  final String hashValue;

  factory BundleManifest.fromJson(Map<String, dynamic> json) {
    final hash = json['hash'] as Map<String, dynamic>? ?? const {};
    return BundleManifest(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      bundleId: json['bundleId'] as String? ?? 'unknown',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      market: json['market'] as String? ?? 'CN_A',
      periods: _stringList(json['periods']),
      futureCompatiblePeriods: _stringList(json['futureCompatiblePeriods']),
      symbolCount: (json['symbolCount'] as num?)?.toInt() ?? 0,
      segmentCount: (json['segmentCount'] as num?)?.toInt() ?? 0,
      segmentLength: (json['segmentLength'] as num?)?.toInt() ?? 30,
      fields: _stringList(json['fields']),
      indicators: _stringList(json['indicators']),
      hashAlgorithm: hash['algorithm'] as String? ?? 'sha256',
      hashValue: hash['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'bundleId': bundleId,
      'createdAt': createdAt.toIso8601String(),
      'market': market,
      'periods': periods,
      'futureCompatiblePeriods': futureCompatiblePeriods,
      'symbolCount': symbolCount,
      'segmentCount': segmentCount,
      'segmentLength': segmentLength,
      'fields': fields,
      'indicators': indicators,
      'hash': {'algorithm': hashAlgorithm, 'value': hashValue},
    };
  }
}

class BundleStock {
  const BundleStock({
    required this.symbol,
    required this.code,
    required this.exchange,
    required this.name,
    required this.period,
    required this.barCount,
    required this.segmentCount,
  });

  final String symbol;
  final String code;
  final String exchange;
  final String name;
  final String period;
  final int barCount;
  final int segmentCount;

  factory BundleStock.fromJson(Map<String, dynamic> json) {
    return BundleStock(
      symbol: json['symbol'] as String? ?? '',
      code: json['code'] as String? ?? '',
      exchange: json['exchange'] as String? ?? '',
      name: json['name'] as String? ?? '',
      period: json['period'] as String? ?? '1d',
      barCount: (json['barCount'] as num?)?.toInt() ?? 0,
      segmentCount: (json['segmentCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'code': code,
      'exchange': exchange,
      'name': name,
      'period': period,
      'barCount': barCount,
      'segmentCount': segmentCount,
    };
  }
}

class SegmentIndexEntry {
  const SegmentIndexEntry({
    required this.segmentId,
    required this.symbol,
    required this.period,
    required this.path,
    required this.contextBars,
    required this.trainingBars,
    required this.tags,
    required this.features,
  });

  final String segmentId;
  final String symbol;
  final String period;
  final String path;
  final int contextBars;
  final int trainingBars;
  final List<String> tags;
  final Map<String, dynamic> features;

  factory SegmentIndexEntry.fromJson(Map<String, dynamic> json) {
    return SegmentIndexEntry(
      segmentId: json['segmentId'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      period: json['period'] as String? ?? '1d',
      path: json['path'] as String? ?? '',
      contextBars: (json['contextBars'] as num?)?.toInt() ?? 20,
      trainingBars: (json['trainingBars'] as num?)?.toInt() ?? 30,
      tags: _stringList(json['tags']),
      features: Map<String, dynamic>.from(json['features'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segmentId': segmentId,
      'symbol': symbol,
      'period': period,
      'path': path,
      'contextBars': contextBars,
      'trainingBars': trainingBars,
      'tags': tags,
      'features': features,
    };
  }
}

class SegmentBar {
  const SegmentBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.amount,
    this.turnoverRate,
    this.ma5,
    this.ma10,
    this.ma20,
    this.ma30,
    this.ma60,
    this.ma120,
    this.macdDiff,
    this.macdDea,
    this.macdHist,
  });

  final String time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double amount;
  final double? turnoverRate;
  final double? ma5;
  final double? ma10;
  final double? ma20;
  final double? ma30;
  final double? ma60;
  final double? ma120;
  final double? macdDiff;
  final double? macdDea;
  final double? macdHist;

  factory SegmentBar.fromJson(Map<String, dynamic> json) {
    return SegmentBar(
      time: json['time'] as String? ?? '',
      open: _asDouble(json['open']),
      high: _asDouble(json['high']),
      low: _asDouble(json['low']),
      close: _asDouble(json['close']),
      volume: _asDouble(json['volume']),
      amount: _asDouble(json['amount']),
      turnoverRate: _asNullableDouble(json['turnoverRate']),
      ma5: _asNullableDouble(json['ma5']),
      ma10: _asNullableDouble(json['ma10']),
      ma20: _asNullableDouble(json['ma20']),
      ma30: _asNullableDouble(json['ma30']),
      ma60: _asNullableDouble(json['ma60']),
      ma120: _asNullableDouble(json['ma120']),
      macdDiff: _asNullableDouble(json['macdDiff']),
      macdDea: _asNullableDouble(json['macdDea']),
      macdHist: _asNullableDouble(json['macdHist']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
      'amount': amount,
      'turnoverRate': turnoverRate,
      'ma5': ma5,
      'ma10': ma10,
      'ma20': ma20,
      'ma30': ma30,
      'ma60': ma60,
      'ma120': ma120,
      'macdDiff': macdDiff,
      'macdDea': macdDea,
      'macdHist': macdHist,
    };
  }
}

class SegmentPayload {
  const SegmentPayload({
    required this.segmentId,
    required this.symbol,
    required this.period,
    required this.contextBars,
    required this.trainingBars,
    required this.bars,
  });

  final String segmentId;
  final String symbol;
  final String period;
  final int contextBars;
  final int trainingBars;
  final List<SegmentBar> bars;

  factory SegmentPayload.fromJson(Map<String, dynamic> json) {
    final rawBars = json['bars'] as List? ?? const [];
    return SegmentPayload(
      segmentId: json['segmentId'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      period: json['period'] as String? ?? '1d',
      contextBars: (json['contextBars'] as num?)?.toInt() ?? 20,
      trainingBars: (json['trainingBars'] as num?)?.toInt() ?? 30,
      bars: rawBars
          .map(
            (item) =>
                SegmentBar.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segmentId': segmentId,
      'symbol': symbol,
      'period': period,
      'contextBars': contextBars,
      'trainingBars': trainingBars,
      'bars': bars.map((bar) => bar.toJson()).toList(),
    };
  }
}

class BundleCatalog {
  const BundleCatalog({
    required this.rootPath,
    required this.manifest,
    required this.stocks,
    required this.segments,
  });

  final String rootPath;
  final BundleManifest manifest;
  final List<BundleStock> stocks;
  final List<SegmentIndexEntry> segments;

  BundleStock? stockBySymbol(String symbol) {
    for (final stock in stocks) {
      if (stock.symbol == symbol) {
        return stock;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'rootPath': rootPath,
      'manifest': manifest.toJson(),
      'stocks': stocks.map((stock) => stock.toJson()).toList(),
      'segments': segments.map((segment) => segment.toJson()).toList(),
    };
  }

  factory BundleCatalog.fromJson(Map<String, dynamic> json) {
    final rawStocks = json['stocks'] as List? ?? const [];
    final rawSegments = json['segments'] as List? ?? const [];
    return BundleCatalog(
      rootPath: json['rootPath'] as String? ?? '',
      manifest: BundleManifest.fromJson(
        Map<String, dynamic>.from(json['manifest'] as Map? ?? const {}),
      ),
      stocks: rawStocks
          .map(
            (item) =>
                BundleStock.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      segments: rawSegments
          .map(
            (item) => SegmentIndexEntry.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

enum TrainingAction { buy, sell }

class TrainingTrade {
  const TrainingTrade({
    required this.action,
    required this.barIndex,
    required this.time,
    required this.price,
    required this.equityAfter,
  });

  final TrainingAction action;
  final int barIndex;
  final String time;
  final double price;
  final double equityAfter;

  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      'barIndex': barIndex,
      'time': time,
      'price': price,
      'equityAfter': equityAfter,
    };
  }

  factory TrainingTrade.fromJson(Map<String, dynamic> json) {
    final rawAction = json['action'] as String?;
    return TrainingTrade(
      action: switch (rawAction) {
        'buy' => TrainingAction.buy,
        'sell' || 'clear' => TrainingAction.sell,
        _ => TrainingAction.buy,
      },
      barIndex: (json['barIndex'] as num?)?.toInt() ?? 0,
      time: json['time'] as String? ?? '',
      price: _asDouble(json['price']),
      equityAfter: _asDouble(json['equityAfter']),
    );
  }
}

class TrainingResult {
  const TrainingResult({
    required this.sessionId,
    required this.segmentId,
    required this.symbol,
    required this.startedAt,
    required this.completedAt,
    required this.initialCash,
    required this.finalEquity,
    required this.totalReturnPct,
    required this.tradeCount,
    required this.buyCount,
    required this.sellCount,
    required this.summary,
    required this.trades,
  });

  final String sessionId;
  final String segmentId;
  final String symbol;
  final DateTime startedAt;
  final DateTime completedAt;
  final double initialCash;
  final double finalEquity;
  final double totalReturnPct;
  final int tradeCount;
  final int buyCount;
  final int sellCount;
  final String summary;
  final List<TrainingTrade> trades;

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'segmentId': segmentId,
      'symbol': symbol,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt.toIso8601String(),
      'initialCash': initialCash,
      'finalEquity': finalEquity,
      'totalReturnPct': totalReturnPct,
      'tradeCount': tradeCount,
      'buyCount': buyCount,
      'sellCount': sellCount,
      'summary': summary,
      'trades': trades.map((trade) => trade.toJson()).toList(),
    };
  }

  String toEncodedJson() => jsonEncode(toJson());

  factory TrainingResult.fromJson(Map<String, dynamic> json) {
    final rawTrades = json['trades'] as List? ?? const [];
    return TrainingResult(
      sessionId: json['sessionId'] as String? ?? '',
      segmentId: json['segmentId'] as String? ?? '',
      symbol: json['symbol'] as String? ?? '',
      startedAt:
          DateTime.tryParse(json['startedAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt:
          DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
      initialCash: _asDouble(json['initialCash']),
      finalEquity: _asDouble(json['finalEquity']),
      totalReturnPct: _asDouble(json['totalReturnPct']),
      tradeCount: (json['tradeCount'] as num?)?.toInt() ?? 0,
      buyCount: (json['buyCount'] as num?)?.toInt() ?? 0,
      sellCount: (json['sellCount'] as num?)?.toInt() ?? 0,
      summary: json['summary'] as String? ?? '',
      trades: rawTrades
          .map(
            (item) =>
                TrainingTrade.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }

  factory TrainingResult.fromEncodedJson(String encoded) {
    return TrainingResult.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );
  }
}

class TrainingSeed {
  const TrainingSeed({
    required this.entry,
    required this.payload,
    required this.stock,
  });

  final SegmentIndexEntry entry;
  final SegmentPayload payload;
  final BundleStock stock;
}

class ImportProgress {
  const ImportProgress({
    required this.message,
    required this.progress,
    required this.isRunning,
    this.error,
  });

  final String message;
  final double progress;
  final bool isRunning;
  final String? error;

  const ImportProgress.idle()
    : message = '',
      progress = 0,
      isRunning = false,
      error = null;

  const ImportProgress.running({required this.message, required this.progress})
    : isRunning = true,
      error = null;

  const ImportProgress.failed({required this.message, required this.error})
    : progress = 0,
      isRunning = false;

  const ImportProgress.done({required this.message})
    : progress = 1,
      isRunning = false,
      error = null;
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

double? _asNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  return _asDouble(value);
}

List<String> _stringList(Object? raw) {
  final list = raw as List? ?? const [];
  return list.map((item) => item.toString()).toList();
}
