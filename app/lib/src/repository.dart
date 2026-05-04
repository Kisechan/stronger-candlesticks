import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

abstract class BundleRepository {
  Future<BundleCatalog?> loadCurrentBundle();
  Future<BundleCatalog> importBundleFromUrl(
    String url, {
    required void Function(ImportProgress progress) onProgress,
  });
  Future<BundleCatalog> seedDemoBundle();
  Future<SegmentPayload> loadSegment(
    BundleCatalog catalog,
    SegmentIndexEntry entry,
  );
  Future<TrainingResult?> loadLatestResult();
  Future<void> saveLatestResult(TrainingResult result);
}

class LocalBundleRepository implements BundleRepository {
  static const _stateFileName = 'app_state.json';

  @override
  Future<BundleCatalog?> loadCurrentBundle() async {
    final state = await _readAppState();
    final bundleId = state['currentBundleId'] as String?;
    if (bundleId == null || bundleId.isEmpty) {
      return null;
    }

    final rootDir = await _bundleRootDirectory();
    final bundleDir = Directory('${rootDir.path}/$bundleId');
    if (!bundleDir.existsSync()) {
      return null;
    }
    return _loadCatalogFromBundleDir(bundleDir);
  }

  @override
  Future<BundleCatalog> importBundleFromUrl(
    String url, {
    required void Function(ImportProgress progress) onProgress,
  }) async {
    onProgress(
      const ImportProgress.running(message: '正在连接数据源', progress: 0.04),
    );

    final uri = Uri.parse(url);
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();

    if (response.statusCode >= 400) {
      throw HttpException('下载失败，HTTP ${response.statusCode}', uri: uri);
    }

    final bytesBuilder = BytesBuilder(copy: false);
    var received = 0;
    final expected = response.contentLength;

    await for (final chunk in response) {
      bytesBuilder.add(chunk);
      received += chunk.length;
      final ratio = expected > 0 ? received / expected : 0.22;
      onProgress(
        ImportProgress.running(
          message: '正在下载数据包',
          progress: ratio.clamp(0.05, 0.55),
        ),
      );
    }

    final archive = ZipDecoder().decodeBytes(bytesBuilder.takeBytes());
    onProgress(
      const ImportProgress.running(message: '正在校验文件结构', progress: 0.62),
    );

    final files = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile) {
        files[file.name] = file;
      }
    }

    final manifest = _readArchiveDecoded(files, 'manifest.json');
    final stocks = _readArchiveDecoded(files, 'stocks.json');
    final segmentIndex = _readArchiveDecoded(files, 'segment_index.json');

    if (manifest is! Map || segmentIndex is! List || stocks is! List) {
      throw const FormatException('bundle 索引文件格式不正确');
    }

    final bundleId = manifest['bundleId'] as String? ?? 'imported_bundle';
    final bundleDir = await _replaceExistingBundle(bundleId: bundleId);

    onProgress(
      const ImportProgress.running(message: '正在写入本地文件', progress: 0.76),
    );
    for (final entry in files.entries) {
      final target = File('${bundleDir.path}/${entry.key}');
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(entry.value.content as List<int>);
    }

    onProgress(
      const ImportProgress.running(message: '正在整理训练索引', progress: 0.92),
    );
    final catalog = await _loadCatalogFromBundleDir(bundleDir);
    await _writeAppState({
      'currentBundleId': catalog.manifest.bundleId,
      'latestResult': (await loadLatestResult())?.toJson(),
    });

    onProgress(const ImportProgress.done(message: '导入完成'));
    return catalog;
  }

  @override
  Future<BundleCatalog> seedDemoBundle() async {
    final bundleId = 'demo_training_bundle';
    final bundleDir = await _replaceExistingBundle(bundleId: bundleId);
    final root = bundleDir.path;
    final demo = _buildDemoBundle();

    for (final entry in demo.entries) {
      final file = File('$root/${entry.key}');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(entry.value),
      );
    }

    final catalog = await _loadCatalogFromBundleDir(bundleDir);
    final state = await _readAppState();
    state['currentBundleId'] = catalog.manifest.bundleId;
    await _writeAppState(state);
    return catalog;
  }

  @override
  Future<SegmentPayload> loadSegment(
    BundleCatalog catalog,
    SegmentIndexEntry entry,
  ) async {
    final file = File('${catalog.rootPath}/${entry.path}');
    final payload =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return SegmentPayload.fromJson(payload);
  }

  @override
  Future<TrainingResult?> loadLatestResult() async {
    final state = await _readAppState();
    final raw = state['latestResult'];
    if (raw is Map<String, dynamic>) {
      return TrainingResult.fromJson(raw);
    }
    if (raw is Map) {
      return TrainingResult.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  @override
  Future<void> saveLatestResult(TrainingResult result) async {
    final state = await _readAppState();
    state['latestResult'] = result.toJson();
    await _writeAppState(state);
  }

  Future<Directory> _replaceExistingBundle({required String bundleId}) async {
    final rootDir = await _bundleRootDirectory();
    if (rootDir.existsSync()) {
      for (final entity in rootDir.listSync()) {
        entity.deleteSync(recursive: true);
      }
    } else {
      rootDir.createSync(recursive: true);
    }
    final bundleDir = Directory('${rootDir.path}/$bundleId');
    bundleDir.createSync(recursive: true);
    return bundleDir;
  }

  Future<Directory> _bundleRootDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    return Directory('${supportDir.path}/kline_training/bundles');
  }

  Future<File> _stateFile() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/kline_training');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/$_stateFileName');
  }

  Future<Map<String, dynamic>> _readAppState() async {
    final file = await _stateFile();
    if (!file.existsSync()) {
      return {};
    }
    final decoded = jsonDecode(await file.readAsString()) as Map;
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _writeAppState(Map<String, dynamic> state) async {
    final file = await _stateFile();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(state));
  }

  Future<BundleCatalog> _loadCatalogFromBundleDir(Directory bundleDir) async {
    final manifestFile = File('${bundleDir.path}/manifest.json');
    final stocksFile = File('${bundleDir.path}/stocks.json');
    final indexFile = File('${bundleDir.path}/segment_index.json');

    final manifest = BundleManifest.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(await manifestFile.readAsString()) as Map,
      ),
    );
    final stocksJson = jsonDecode(await stocksFile.readAsString()) as List;
    final segmentsJson = jsonDecode(await indexFile.readAsString()) as List;

    final stocks = stocksJson
        .map(
          (item) =>
              BundleStock.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final segments = segmentsJson
        .map(
          (item) => SegmentIndexEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    return BundleCatalog(
      rootPath: bundleDir.path,
      manifest: manifest,
      stocks: stocks,
      segments: segments,
    );
  }

  dynamic _readArchiveDecoded(Map<String, ArchiveFile> files, String path) {
    final file = files[path];
    if (file == null) {
      throw FormatException('bundle 缺少 $path');
    }

    final bytes = Uint8List.fromList(file.content as List<int>);
    return jsonDecode(utf8.decode(bytes));
  }
}

class MemoryBundleRepository implements BundleRepository {
  MemoryBundleRepository({this.seedDemoOnLoad = false});

  final bool seedDemoOnLoad;
  BundleCatalog? _catalog;
  final Map<String, SegmentPayload> _segments = {};
  TrainingResult? _latestResult;

  @override
  Future<BundleCatalog?> loadCurrentBundle() async {
    if (_catalog == null && seedDemoOnLoad) {
      await seedDemoBundle();
    }
    return _catalog;
  }

  @override
  Future<BundleCatalog> importBundleFromUrl(
    String url, {
    required void Function(ImportProgress progress) onProgress,
  }) async {
    onProgress(
      const ImportProgress.running(message: '测试仓库不支持真实导入', progress: 0.2),
    );
    final result = await seedDemoBundle();
    onProgress(const ImportProgress.done(message: '已加载演示数据'));
    return result;
  }

  @override
  Future<SegmentPayload> loadSegment(
    BundleCatalog catalog,
    SegmentIndexEntry entry,
  ) async {
    return _segments[entry.segmentId]!;
  }

  @override
  Future<TrainingResult?> loadLatestResult() async => _latestResult;

  @override
  Future<void> saveLatestResult(TrainingResult result) async {
    _latestResult = result;
  }

  @override
  Future<BundleCatalog> seedDemoBundle() async {
    final demo = _buildDemoBundle();
    final manifest = BundleManifest.fromJson(
      Map<String, dynamic>.from(demo['manifest.json']!),
    );
    final stocks = (demo['stocks.json']! as List)
        .map(
          (item) =>
              BundleStock.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
    final segmentsIndex = (demo['segment_index.json']! as List)
        .map(
          (item) => SegmentIndexEntry.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    _catalog = BundleCatalog(
      rootPath: '/memory',
      manifest: manifest,
      stocks: stocks,
      segments: segmentsIndex,
    );
    _segments.clear();
    for (final entry in segmentsIndex) {
      _segments[entry.segmentId] = SegmentPayload.fromJson(
        Map<String, dynamic>.from(demo[entry.path]!),
      );
    }
    return _catalog!;
  }
}

Map<String, dynamic> _buildDemoBundle() {
  const contextBars = 30;
  const trainingBars = 30;
  final symbols = [
    ('600519.SH', '贵州茅台'),
    ('300750.SZ', '宁德时代'),
    ('000001.SZ', '平安银行'),
  ];
  final files = <String, dynamic>{};
  final stocks = <Map<String, dynamic>>[];
  final segmentsIndex = <Map<String, dynamic>>[];
  var totalSegments = 0;

  for (final (index, stockTuple) in symbols.indexed) {
    final symbol = stockTuple.$1;
    final name = stockTuple.$2;
    final bars = _generateBars(
      seed: 42 + index * 9,
      count: 124,
      symbolIndex: index,
    );
    final stockSegments = <Map<String, dynamic>>[];
    final totalBarsPerSegment = contextBars + trainingBars;
    final maxStart = bars.length - totalBarsPerSegment;
    for (var start = 20; start <= maxStart; start += 10) {
      final window = bars.sublist(start, start + contextBars + trainingBars);
      final segmentId = '${symbol.replaceAll('.', '_')}_1d_$start';
      final path = 'segments/daily/$symbol/$segmentId.json';
      final features = {
        'startTime': window.first['time'],
        'decisionTime': window[contextBars - 1]['time'],
        'endTime': window.last['time'],
        'startClose': window[contextBars - 1]['close'],
        'endClose': window.last['close'],
        'returnPct':
            (((window.last['close'] as double) -
                        (window[contextBars - 1]['close'] as double)) /
                    (window[contextBars - 1]['close'] as double) *
                    100)
                .toStringAsFixed(3),
      };
      final segment = {
        'segmentId': segmentId,
        'symbol': symbol,
        'period': '1d',
        'contextBars': contextBars,
        'trainingBars': trainingBars,
        'bars': window,
      };
      files[path] = segment;
      final indexEntry = {
        'segmentId': segmentId,
        'symbol': symbol,
        'period': '1d',
        'path': path,
        'contextBars': contextBars,
        'trainingBars': trainingBars,
        'tags': <String>[],
        'features': features,
      };
      stockSegments.add(indexEntry);
      segmentsIndex.add(indexEntry);
      totalSegments += 1;
    }
    stocks.add({
      'symbol': symbol,
      'name': name,
      'period': '1d',
      'barCount': bars.length,
      'segmentCount': stockSegments.length,
    });
  }

  files['manifest.json'] = {
    'schemaVersion': 1,
    'bundleId': 'demo_training_bundle',
    'createdAt': DateTime.now().toIso8601String(),
    'market': 'CN_A',
    'periods': ['1d'],
    'futureCompatiblePeriods': ['1m', '5m', '15m'],
    'symbolCount': stocks.length,
    'segmentCount': totalSegments,
    'segmentLength': trainingBars,
    'fields': ['time', 'open', 'high', 'low', 'close', 'volume', 'amount'],
    'indicators': ['ma5', 'ma10', 'ma20', 'macd'],
    'hash': {'algorithm': 'demo', 'value': 'demo'},
  };
  files['stocks.json'] = stocks;
  files['segment_index.json'] = segmentsIndex;
  return files;
}

List<Map<String, dynamic>> _generateBars({
  required int seed,
  required int count,
  required int symbolIndex,
}) {
  final random = Random(seed);
  final closes = <double>[];
  final bars = <Map<String, dynamic>>[];
  var lastClose = 12.0 + symbolIndex * 18.0;

  for (var i = 0; i < count; i++) {
    final date = DateTime(2023, 1, 1).add(Duration(days: i));
    final drift =
        sin(i / 5.0) * 0.4 +
        cos(i / 9.0) * 0.22 +
        (random.nextDouble() - 0.5) * 0.35;
    final open = max(2.0, lastClose + drift * 0.45);
    final close = max(2.0, open + drift);
    final high = max(open, close) + 0.2 + random.nextDouble() * 0.65;
    final low = min(open, close) - 0.18 - random.nextDouble() * 0.5;
    final volume = 1200000 + random.nextInt(800000) + (i * 1100);
    final amount = volume * close;

    closes.add(close);
    final ma5 = _ma(closes, 5);
    final ma10 = _ma(closes, 10);
    final ma20 = _ma(closes, 20);
    final macdValues = _macd(closes);

    bars.add({
      'time': _formatDate(date),
      'open': _round(open),
      'high': _round(high),
      'low': _round(low),
      'close': _round(close),
      'volume': volume.toDouble(),
      'amount': _round(amount),
      'ma5': ma5 == null ? null : _round(ma5),
      'ma10': ma10 == null ? null : _round(ma10),
      'ma20': ma20 == null ? null : _round(ma20),
      'macdDiff': _round(macdValues.$1),
      'macdDea': _round(macdValues.$2),
      'macdHist': _round(macdValues.$3),
    });
    lastClose = close;
  }

  return bars.where((bar) => bar['ma20'] != null).toList();
}

double? _ma(List<double> values, int period) {
  if (values.length < period) {
    return null;
  }
  final slice = values.sublist(values.length - period);
  return slice.reduce((a, b) => a + b) / period;
}

(double, double, double) _macd(List<double> values) {
  var ema12 = values.first;
  var ema26 = values.first;
  var dea = 0.0;
  for (final close in values) {
    ema12 = ema12 * (11 / 13) + close * (2 / 13);
    ema26 = ema26 * (25 / 27) + close * (2 / 27);
    final diff = ema12 - ema26;
    dea = dea * (8 / 10) + diff * (2 / 10);
  }
  final diff = ema12 - ema26;
  final hist = (diff - dea) * 2;
  return (diff, dea, hist);
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

double _round(double value) => double.parse(value.toStringAsFixed(4));
