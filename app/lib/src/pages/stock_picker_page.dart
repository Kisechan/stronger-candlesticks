import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../theme.dart';
import '../ui_components.dart';

class StockPickerPage extends StatelessWidget {
  const StockPickerPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final stocks = controller.catalog?.stocks ?? const [];

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('选择股票'),
        border: null,
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          itemBuilder: (context, index) {
            final stock = stocks[index];
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(stock.symbol),
              child: SectionSurface(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.name.isEmpty ? stock.symbol : stock.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stock.symbol,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${stock.segmentCount} 段',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (_, index) => const SizedBox(height: 12),
          itemCount: stocks.length,
        ),
      ),
    );
  }
}
