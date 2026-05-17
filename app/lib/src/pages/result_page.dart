import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../models.dart';
import '../theme.dart';
import '../ui_components.dart';
import 'training_page.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key, required this.controller, required this.result});

  final AppController controller;
  final TrainingResult result;

  @override
  Widget build(BuildContext context) {
    final returnColor = result.totalReturnPct >= 0
        ? AppColors.accent
        : AppColors.danger;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('结果'),
        border: null,
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            Text(
              result.totalReturnPct >= 0 ? '这轮训练赚到了' : '这轮训练偏弱',
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              result.summary,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SectionSurface(
              children: [
                InfoRow(label: '标的', value: result.symbol),
                InfoRow(
                  label: '总收益率',
                  value:
                      '${result.totalReturnPct >= 0 ? '+' : ''}${result.totalReturnPct.toStringAsFixed(2)}%',
                  valueColor: returnColor,
                ),
                InfoRow(
                  label: '最终权益',
                  value: result.finalEquity.toStringAsFixed(2),
                ),
                InfoRow(label: '交易次数', value: '${result.tradeCount}'),
                InfoRow(label: '买入次数', value: '${result.buyCount}'),
                InfoRow(label: '卖出次数', value: '${result.sellCount}'),
              ],
            ),
            const SizedBox(height: 20),
            SectionSurface(
              children: [
                const Text(
                  '本次操作',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                ...result.trades.map(
                  (trade) => Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_actionLabel(trade.action)} · ${trade.time}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        trade.price.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryActionButton(
              label: '再来一局',
              onPressed: () async {
                final seed = await controller.createRandomSeed();
                if (!context.mounted || seed == null) {
                  return;
                }
                Navigator.of(context).pushReplacement(
                  CupertinoPageRoute(
                    builder: (_) =>
                        TrainingPage(controller: controller, seed: seed),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            SecondaryActionButton(
              label: '返回首页',
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
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
