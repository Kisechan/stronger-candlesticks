import 'dart:async';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/cupertino.dart';

import 'models.dart';
import 'pages/home_page.dart';
import 'repository.dart';
import 'theme.dart';

class KlineTrainingApp extends StatefulWidget {
  const KlineTrainingApp({super.key, required this.repository});

  final BundleRepository repository;

  @override
  State<KlineTrainingApp> createState() => _KlineTrainingAppState();
}

class _KlineTrainingAppState extends State<KlineTrainingApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController(widget.repository)..bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Stronger Candlesticks',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _AppShell(controller: _controller),
    );
  }
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return controller.isBootstrapping
            ? const _SplashPage()
            : HomePage(controller: controller);
      },
    );
  }
}

class AppController extends ChangeNotifier {
  AppController(this._repository) {
    _downloadSubscription = FileDownloader().updates.listen(
      _handleDownloadUpdate,
    );
  }

  final BundleRepository _repository;
  final Random _random = Random();
  StreamSubscription<TaskUpdate>? _downloadSubscription;

  bool _isBootstrapping = true;
  List<BundleCatalog> _bundles = const [];
  BundleCatalog? _catalog;
  TrainingResult? _latestResult;
  ImportProgress _importProgress = const ImportProgress.idle();
  String? _errorMessage;
  String? _activeDownloadTaskId;
  bool _isImportingDownloadedArchive = false;

  bool get isBootstrapping => _isBootstrapping;
  List<BundleCatalog> get bundles => List.unmodifiable(_bundles);
  BundleCatalog? get catalog => _catalog;
  TrainingResult? get latestResult => _latestResult;
  ImportProgress get importProgress => _importProgress;
  String? get errorMessage => _errorMessage;
  bool get hasBundle => _catalog != null;

  Future<void> bootstrap() async {
    try {
      _bundles = await _repository.loadBundles();
      _catalog = await _repository.loadCurrentBundle();
      if (_catalog == null && _bundles.isNotEmpty) {
        _catalog = _bundles.first;
        await _repository.selectBundle(_catalog!.manifest.bundleId);
      }
      _latestResult = await _repository.loadLatestResult();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> importFromUrl(String url) async {
    _errorMessage = null;
    final uri = _normalizeRemoteBundleUri(url);
    final taskId = 'bundle-${DateTime.now().millisecondsSinceEpoch}';
    final task = DownloadTask(
      taskId: taskId,
      url: uri.toString(),
      filename: '$taskId.ktpkg',
      baseDirectory: BaseDirectory.applicationSupport,
      directory: 'kline_training/incoming',
      updates: Updates.statusAndProgress,
    );

    _activeDownloadTaskId = taskId;
    _isImportingDownloadedArchive = false;
    _importProgress = const ImportProgress.running(
      message: '下载任务已加入队列，切到后台也会继续',
      progress: 0.03,
    );
    notifyListeners();

    try {
      final enqueued = await FileDownloader().enqueue(task);
      if (!enqueued) {
        throw Exception('后台下载任务创建失败');
      }
    } catch (error) {
      _activeDownloadTaskId = null;
      _importProgress = ImportProgress.failed(
        message: '导入失败',
        error: error.toString(),
      );
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> _handleDownloadUpdate(TaskUpdate update) async {
    if (update.task.taskId != _activeDownloadTaskId) {
      return;
    }

    switch (update) {
      case TaskProgressUpdate():
        final rawProgress = update.progress.isFinite ? update.progress : 0.0;
        _importProgress = ImportProgress.running(
          message: '正在下载数据包',
          progress: (0.06 + rawProgress.clamp(0.0, 1.0) * 0.62).clamp(
            0.06,
            0.68,
          ),
        );
        notifyListeners();
      case TaskStatusUpdate():
        await _handleDownloadStatusUpdate(update);
    }
  }

  Future<void> _handleDownloadStatusUpdate(TaskStatusUpdate update) async {
    switch (update.status) {
      case TaskStatus.running:
      case TaskStatus.enqueued:
        _importProgress = const ImportProgress.running(
          message: '后台下载中，切到后台也会继续',
          progress: 0.05,
        );
        notifyListeners();
      case TaskStatus.complete:
        if (_isImportingDownloadedArchive) {
          return;
        }
        _isImportingDownloadedArchive = true;
        _importProgress = const ImportProgress.running(
          message: '下载完成，正在导入本地数据',
          progress: 0.72,
        );
        notifyListeners();
        try {
          final archivePath = await update.task.filePath();
          _catalog = await _repository.importBundleFromArchiveFile(
            archivePath,
            onProgress: (progress) {
              if (progress.isRunning) {
                _importProgress = ImportProgress.running(
                  message: progress.message,
                  progress: 0.72 + progress.progress * 0.28,
                );
              } else if (progress.error != null) {
                _importProgress = ImportProgress.failed(
                  message: progress.message,
                  error: progress.error!,
                );
              } else {
                _importProgress = ImportProgress.done(
                  message: progress.message,
                );
              }
              notifyListeners();
            },
          );
          _bundles = await _repository.loadBundles();
          _importProgress = const ImportProgress.done(message: '导入完成');
          _activeDownloadTaskId = null;
          _isImportingDownloadedArchive = false;
          notifyListeners();
        } catch (error) {
          _activeDownloadTaskId = null;
          _isImportingDownloadedArchive = false;
          _importProgress = ImportProgress.failed(
            message: '导入失败',
            error: error.toString(),
          );
          _errorMessage = error.toString();
          notifyListeners();
        }
      case TaskStatus.failed:
        _activeDownloadTaskId = null;
        _isImportingDownloadedArchive = false;
        _importProgress = ImportProgress.failed(
          message: '导入失败',
          error: update.exception?.description ?? '下载失败，请检查地址和网络',
        );
        _errorMessage = _importProgress.error;
        notifyListeners();
      case TaskStatus.canceled:
      case TaskStatus.notFound:
        _activeDownloadTaskId = null;
        _isImportingDownloadedArchive = false;
        _importProgress = ImportProgress.failed(
          message: '导入失败',
          error: '下载任务未完成或已被取消',
        );
        _errorMessage = _importProgress.error;
        notifyListeners();
      default:
        break;
    }
  }

  Uri _normalizeRemoteBundleUri(String rawUrl) {
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

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadDemoBundle() async {
    _errorMessage = null;
    _importProgress = const ImportProgress.running(
      message: '正在写入演示数据',
      progress: 0.32,
    );
    notifyListeners();

    try {
      _catalog = await _repository.seedDemoBundle();
      _bundles = await _repository.loadBundles();
      _importProgress = const ImportProgress.done(message: '已加载演示数据');
    } catch (error) {
      _importProgress = ImportProgress.failed(
        message: '演示数据加载失败',
        error: error.toString(),
      );
      _errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> selectBundle(String bundleId) async {
    await _repository.selectBundle(bundleId);
    _bundles = await _repository.loadBundles();
    _catalog = await _repository.loadCurrentBundle();
    notifyListeners();
  }

  Future<void> deleteBundle(String bundleId) async {
    await _repository.deleteBundle(bundleId);
    _bundles = await _repository.loadBundles();
    _catalog = await _repository.loadCurrentBundle();
    notifyListeners();
  }

  Future<TrainingSeed?> createRandomSeed({String? symbol}) async {
    final catalog = _catalog;
    if (catalog == null || catalog.segments.isEmpty) {
      return null;
    }

    final source = symbol == null
        ? catalog.segments
        : catalog.segments.where((entry) => entry.symbol == symbol).toList();
    if (source.isEmpty) {
      return null;
    }

    final entry = source[_random.nextInt(source.length)];
    final payload = await _repository.loadSegment(catalog, entry);
    final stock =
        catalog.stockBySymbol(entry.symbol) ??
        BundleStock(
          symbol: entry.symbol,
          code: entry.symbol.split('.').first,
          exchange: entry.symbol.split('.').last,
          name: entry.symbol,
          period: entry.period,
          barCount: payload.bars.length,
          segmentCount: 1,
        );

    return TrainingSeed(entry: entry, payload: payload, stock: stock);
  }

  Future<void> recordResult(TrainingResult result) async {
    _latestResult = result;
    await _repository.saveLatestResult(result);
    notifyListeners();
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stronger Candlesticks',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '正在准备本地训练环境',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
