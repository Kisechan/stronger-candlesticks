import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../theme.dart';
import '../ui_components.dart';

class BundleLibraryPage extends StatefulWidget {
  const BundleLibraryPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<BundleLibraryPage> createState() => _BundleLibraryPageState();
}

class _BundleLibraryPageState extends State<BundleLibraryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Bundle 仓库'),
        border: null,
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final currentId = widget.controller.catalog?.manifest.bundleId;
            final query = _searchController.text.trim().toLowerCase();
            final bundles = widget.controller.bundles.where((bundle) {
              if (query.isEmpty) {
                return true;
              }
              final haystack =
                  '${bundle.manifest.bundleId} ${bundle.manifest.market}'
                      .toLowerCase();
              return haystack.contains(query);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                CupertinoSearchTextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                if (bundles.isEmpty)
                  const SectionSurface(
                    children: [
                      Text(
                        '没有匹配的 bundle',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  )
                else
                  ...bundles.map(
                    (bundle) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SectionSurface(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bundle.manifest.bundleId,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${bundle.manifest.market} · ${bundle.manifest.symbolCount} 股 · ${bundle.manifest.segmentCount} 段',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (bundle.manifest.bundleId == currentId)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentSoft,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    '当前',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          InfoRow(
                            label: '创建时间',
                            value: bundle.manifest.createdAt
                                .toLocal()
                                .toString()
                                .substring(0, 16),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: PrimaryActionButton(
                                  label: bundle.manifest.bundleId == currentId
                                      ? '正在使用'
                                      : '切换到此 Bundle',
                                  enabled:
                                      bundle.manifest.bundleId != currentId,
                                  onPressed: () async {
                                    await widget.controller.selectBundle(
                                      bundle.manifest.bundleId,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          SecondaryActionButton(
                            label: '删除',
                            color: AppColors.danger,
                            onPressed: () async {
                              await _confirmDelete(bundle.manifest.bundleId);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String bundleId) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('删除这个 Bundle？'),
          message: Text(bundleId),
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.controller.deleteBundle(bundleId);
              },
              child: const Text('删除'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        );
      },
    );
  }
}
