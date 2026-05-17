import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';

abstract class BundleRepository {
  Future<BundleCatalog?> loadCurrentBundle();
  Future<List<BundleCatalog>> loadBundles();
  Future<BundleCatalog> importBundleFromUrl(
    String url, {
    required void Function(ImportProgress progress) onProgress,
  });
  Future<BundleCatalog> seedDemoBundle();
  Future<void> selectBundle(String bundleId);
  Future<void> deleteBundle(String bundleId);
  Future<SegmentPayload> loadSegment(
    BundleCatalog catalog,
    SegmentIndexEntry entry,
  );
  Future<TrainingResult?> loadLatestResult();
  Future<void> saveLatestResult(TrainingResult result);
}

class LocalBundleRepository implements BundleRepository {
  static const _stateFileName = 'app_state.json';
  static const _requestTimeout = Duration(seconds: 20);

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
  Future<List<BundleCatalog>> loadBundles() async {
    final rootDir = await _bundleRootDirectory();
    if (!rootDir.existsSync()) {
      return const [];
    }

    final bundles = <BundleCatalog>[];
    for (final entity in rootDir.listSync()) {
      if (entity is! Directory) {
        continue;
      }
      final manifestFile = File('${entity.path}/manifest.json');
      final stocksFile = File('${entity.path}/stocks.json');
      final indexFile = File('${entity.path}/segment_index.json');
      if (!manifestFile.existsSync() ||
          !stocksFile.existsSync() ||
          !indexFile.existsSync()) {
        continue;
      }
      bundles.add(await _loadCatalogFromBundleDir(entity));
    }

    bundles.sort(
      (left, right) =>
          right.manifest.createdAt.compareTo(left.manifest.createdAt),
    );
    return bundles;
  }

  @override
  Future<BundleCatalog> importBundleFromUrl(
    String url, {
    required void Function(ImportProgress progress) onProgress,
  }) async {
    onProgress(
      const ImportProgress.running(message: '正在连接数据源', progress: 0.04),
    );

    final uri = _normalizeBundleUri(url);
    final client = HttpClient()..connectionTimeout = _requestTimeout;

    try {
      final request = await client.getUrl(uri).timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);

      if (response.statusCode >= 400) {
        throw HttpException('下载失败，HTTP ${response.statusCode}', uri: uri);
      }

      final bytesBuilder = BytesBuilder(copy: false);
      var received = 0;
      final expected = response.contentLength;

      await for (final chunk in response.timeout(_requestTimeout)) {
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

      final archiveBytes = bytesBuilder.takeBytes();
      final archive = ZipDecoder().decodeBytes(archiveBytes);
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
      final bundleDir = await _prepareBundleDirectory(bundleId: bundleId);
      final persistedArchive = File('${bundleDir.path}/bundle.ktpkg');

      onProgress(
        const ImportProgress.running(message: '正在写入本地文件', progress: 0.76),
      );
      persistedArchive.writeAsBytesSync(archiveBytes, flush: true);
      for (final file in archive.files) {
        if (!file.isFile) {
          continue;
        }
        final target = File('${bundleDir.path}/${file.name}');
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(file.content as List<int>, flush: true);
      }

      onProgress(
        const ImportProgress.running(message: '正在整理训练索引', progress: 0.92),
      );
      final catalog = await _loadCatalogFromBundleDir(bundleDir);
      _validateCatalog(catalog);
      await _writeAppState({
        'currentBundleId': catalog.manifest.bundleId,
        'latestResult': (await loadLatestResult())?.toJson(),
      });

      onProgress(const ImportProgress.done(message: '导入完成'));
      return catalog;
    } on SocketException catch (error) {
      throw Exception(_describeSocketException(error, uri));
    } on TimeoutException {
      throw Exception('连接超时，请检查网络、域名可达性或稍后重试');
    } on FormatException catch (error) {
      throw Exception('数据包格式错误：${error.message}');
    } on HttpException catch (error) {
      throw Exception(error.message);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<BundleCatalog> seedDemoBundle() async {
    final bundleId = 'demo_training_bundle';
    final bundleDir = await _prepareBundleDirectory(bundleId: bundleId);
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
  Future<void> selectBundle(String bundleId) async {
    final state = await _readAppState();
    state['currentBundleId'] = bundleId;
    await _writeAppState(state);
  }

  @override
  Future<void> deleteBundle(String bundleId) async {
    final rootDir = await _bundleRootDirectory();
    final bundleDir = Directory('${rootDir.path}/$bundleId');
    if (bundleDir.existsSync()) {
      bundleDir.deleteSync(recursive: true);
    }

    final state = await _readAppState();
    if (state['currentBundleId'] == bundleId) {
      final bundles = await loadBundles();
      state['currentBundleId'] = bundles.isEmpty
          ? null
          : bundles.first.manifest.bundleId;
      await _writeAppState(state);
    }
  }

  @override
  Future<SegmentPayload> loadSegment(
    BundleCatalog catalog,
    SegmentIndexEntry entry,
  ) async {
    final extractedFile = File('${catalog.rootPath}/${entry.path}');
    if (extractedFile.existsSync()) {
      final payload =
          jsonDecode(await extractedFile.readAsString())
              as Map<String, dynamic>;
      return SegmentPayload.fromJson(payload);
    }

    final bundleArchiveFile = File('${catalog.rootPath}/bundle.ktpkg');
    if (!bundleArchiveFile.existsSync()) {
      throw StateError('bundle archive not found for ${entry.segmentId}');
    }

    final archive = ZipDecoder().decodeBytes(
      await bundleArchiveFile.readAsBytes(),
    );
    ArchiveFile? matchedFile;
    for (final file in archive.files) {
      if (file.isFile && file.name == entry.path) {
        matchedFile = file;
        break;
      }
    }
    if (matchedFile == null) {
      throw StateError('segment ${entry.path} missing from bundle archive');
    }

    final payload =
        jsonDecode(
              utf8.decode(Uint8List.fromList(matchedFile.content as List<int>)),
            )
            as Map<String, dynamic>;
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

  Future<Directory> _prepareBundleDirectory({required String bundleId}) async {
    final rootDir = await _bundleRootDirectory();
    if (!rootDir.existsSync()) {
      rootDir.createSync(recursive: true);
    }
    final bundleDir = Directory('${rootDir.path}/$bundleId');
    if (bundleDir.existsSync()) {
      bundleDir.deleteSync(recursive: true);
    }
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

  void _validateCatalog(BundleCatalog catalog) {
    if (catalog.manifest.symbolCount != catalog.stocks.length) {
      throw const FormatException('bundle 股票索引数量不一致');
    }
    if (catalog.manifest.segmentCount != catalog.segments.length) {
      throw const FormatException('bundle segment 索引数量不一致');
    }
  }

  Uri _normalizeBundleUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.parse(trimmed);
    if (!uri.hasScheme) {
      throw const FormatException('URL 缺少协议头，请使用 http:// 或 https://');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const FormatException('仅支持 http:// 或 https:// 下载地址');
    }
    if (uri.host.isEmpty) {
      throw const FormatException('URL 缺少主机名');
    }
    return uri;
  }

  String _describeSocketException(SocketException error, Uri uri) {
    final message = error.message.toLowerCase();
    if (message.contains('failed host lookup') ||
        message.contains('no address associated with hostname') ||
        error.osError?.errorCode == 7) {
      return '域名解析失败：${uri.host}。请检查域名是否有效、手机网络是否可用，或尝试改用 https:// 地址';
    }
    if (message.contains('network is unreachable')) {
      return '当前网络不可达，请检查手机是否联网';
    }
    if (message.contains('connection refused')) {
      return '目标服务器拒绝连接，请检查服务端是否已启动';
    }
    return '网络连接失败：${error.message}';
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
  Future<List<BundleCatalog>> loadBundles() async {
    final catalog = await loadCurrentBundle();
    return catalog == null ? const [] : [catalog];
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
  Future<void> selectBundle(String bundleId) async {}

  @override
  Future<void> deleteBundle(String bundleId) async {
    if (_catalog?.manifest.bundleId == bundleId) {
      _catalog = null;
      _segments.clear();
    }
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
  const contextBars = 20;
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
      count: 220,
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
      'code': symbol.split('.').first,
      'exchange': symbol.split('.').last,
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
    'fields': [
      'time',
      'open',
      'high',
      'low',
      'close',
      'volume',
      'amount',
      'turnoverRate',
    ],
    'indicators': ['ma5', 'ma10', 'ma20', 'ma30', 'ma60', 'ma120', 'macd'],
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
      'turnoverRate': _round(0.8 + random.nextDouble() * 4.6),
      'ma5': ma5 == null ? null : _round(ma5),
      'ma10': ma10 == null ? null : _round(ma10),
      'ma20': ma20 == null ? null : _round(ma20),
      'ma30': _ma(closes, 30) == null ? null : _round(_ma(closes, 30)!),
      'ma60': _ma(closes, 60) == null ? null : _round(_ma(closes, 60)!),
      'ma120': _ma(closes, 120) == null ? null : _round(_ma(closes, 120)!),
      'macdDiff': _round(macdValues.$1),
      'macdDea': _round(macdValues.$2),
      'macdHist': _round(macdValues.$3),
    });
    lastClose = close;
  }

  return bars.where((bar) => bar['ma120'] != null).toList();
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
