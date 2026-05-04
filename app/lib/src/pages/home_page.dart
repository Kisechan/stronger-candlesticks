import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../theme.dart';
import '../ui_components.dart';
import 'import_page.dart';
import 'stock_picker_page.dart';
import 'training_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(
            largeTitle: Text('训练'),
            border: null,
            transitionBetweenRoutes: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            sliver: SliverList.list(
              children: [
                const Text(
                  '离线 K 线推演',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                if (controller.errorMessage != null) ...[
                  SectionSurface(
                    children: [
                      const Text(
                        '当前状态',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        controller.errorMessage!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                if (controller.catalog == null)
                  _EmptyBundleSection(controller: controller)
                else
                  _ReadySection(controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBundleSection extends StatelessWidget {
  const _EmptyBundleSection({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionSurface(
          children: [
            const Text(
              '还没有训练数据',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Text(
              '先导入一个 .ktpkg 数据包，之后即可离线开始训练。为了方便上手，也可以先加载一份演示数据。',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            PrimaryActionButton(
              label: '导入数据包',
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => ImportPage(controller: controller),
                  ),
                );
              },
            ),
            SecondaryActionButton(
              label: '先试试演示数据',
              onPressed: controller.loadDemoBundle,
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadySection extends StatelessWidget {
  const _ReadySection({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog!;
    final latest = controller.latestResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionSurface(
          children: [
            const Text(
              '当前数据包',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            InfoRow(label: 'Bundle', value: catalog.manifest.bundleId),
            InfoRow(label: '股票数', value: '${catalog.manifest.symbolCount}'),
            InfoRow(
              label: 'Segment 数',
              value: '${catalog.manifest.segmentCount}',
            ),
            InfoRow(label: '导入市场', value: catalog.manifest.market),
          ],
        ),
        const SizedBox(height: 18),
        SectionSurface(
          children: [
            const Text(
              '开始一轮训练',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const Text(
              '默认从当前 bundle 中随机抽取一个 segment，保持节奏感，尽量减少选择成本。',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            PrimaryActionButton(
              label: '开始训练',
              onPressed: () => _showLaunchSheet(context),
            ),
            SecondaryActionButton(
              label: '导入或替换数据包',
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => ImportPage(controller: controller),
                  ),
                );
              },
            ),
          ],
        ),
        if (latest != null) ...[
          const SizedBox(height: 18),
          SectionSurface(
            children: [
              const Text(
                '最近一次训练',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              InfoRow(label: '标的', value: latest.symbol),
              InfoRow(
                label: '收益率',
                value:
                    '${latest.totalReturnPct >= 0 ? '+' : ''}${latest.totalReturnPct.toStringAsFixed(2)}%',
                valueColor: latest.totalReturnPct >= 0
                    ? AppColors.accent
                    : AppColors.danger,
              ),
              InfoRow(label: '操作数', value: '${latest.tradeCount}'),
              Text(
                latest.summary,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _showLaunchSheet(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) {
        return CupertinoActionSheet(
          title: const Text('开始训练'),
          message: const Text('可以直接随机开始，也可以先按股票选择。'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(context).pop();
                await _launchTraining(context);
              },
              child: const Text('随机开始'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(context).pop();
                final symbol = await Navigator.of(context).push<String>(
                  CupertinoPageRoute(
                    builder: (_) => StockPickerPage(controller: controller),
                  ),
                );
                if (symbol != null) {
                  if (!context.mounted) {
                    return;
                  }
                  await _launchTraining(context, symbol: symbol);
                }
              },
              child: const Text('按股票选择'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            isDefaultAction: true,
            child: const Text('取消'),
          ),
        );
      },
    );
  }

  Future<void> _launchTraining(BuildContext context, {String? symbol}) async {
    final seed = await controller.createRandomSeed(symbol: symbol);
    if (!context.mounted || seed == null) {
      return;
    }
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => TrainingPage(controller: controller, seed: seed),
      ),
    );
  }
}
