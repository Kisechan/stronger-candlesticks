import 'dart:math';

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
  AppController(this._repository);

  final BundleRepository _repository;
  final Random _random = Random();

  bool _isBootstrapping = true;
  BundleCatalog? _catalog;
  TrainingResult? _latestResult;
  ImportProgress _importProgress = const ImportProgress.idle();
  String? _errorMessage;

  bool get isBootstrapping => _isBootstrapping;
  BundleCatalog? get catalog => _catalog;
  TrainingResult? get latestResult => _latestResult;
  ImportProgress get importProgress => _importProgress;
  String? get errorMessage => _errorMessage;
  bool get hasBundle => _catalog != null;

  Future<void> bootstrap() async {
    try {
      _catalog = await _repository.loadCurrentBundle();
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
    _importProgress = const ImportProgress.running(
      message: '准备导入',
      progress: 0.02,
    );
    notifyListeners();

    try {
      _catalog = await _repository.importBundleFromUrl(
        url,
        onProgress: (progress) {
          _importProgress = progress;
          notifyListeners();
        },
      );
      _importProgress = const ImportProgress.done(message: '导入完成');
    } catch (error) {
      _importProgress = ImportProgress.failed(
        message: '导入失败',
        error: error.toString(),
      );
      _errorMessage = error.toString();
    }
    notifyListeners();
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
