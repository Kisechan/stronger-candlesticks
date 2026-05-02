import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../theme.dart';
import '../ui_components.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.controller.importProgress;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('导入数据'),
        border: null,
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final state = widget.controller.importProgress;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                const Text(
                  '导入 .ktpkg',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '建议使用一个可直接访问的 URL。导入时 App 会下载 zip、解析 manifest、保存 segment 文件，并将索引常驻在本地。',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                SectionSurface(
                  children: [
                    const Text(
                      '数据包地址',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoTextField(
                      controller: _urlController,
                      placeholder: 'https://example.com/training.ktpkg',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    PrimaryActionButton(
                      label: state.isRunning ? '正在导入…' : '下载并导入',
                      enabled: !state.isRunning,
                      onPressed: () async {
                        final url = _urlController.text.trim();
                        if (url.isEmpty) {
                          return;
                        }
                        await widget.controller.importFromUrl(url);
                      },
                    ),
                    SecondaryActionButton(
                      label: '加载演示数据',
                      onPressed: state.isRunning
                          ? null
                          : widget.controller.loadDemoBundle,
                    ),
                  ],
                ),
                if (state.isRunning ||
                    state.error != null ||
                    progress.message.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionSurface(
                    children: [
                      const Text(
                        '导入进度',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ThinProgressBar(progress: state.progress),
                      Text(
                        state.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (state.error != null)
                        Text(
                          state.error!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.danger,
                            height: 1.45,
                          ),
                        ),
                    ],
                  ),
                ],
                if (!state.isRunning && state.progress == 1) ...[
                  const SizedBox(height: 18),
                  PrimaryActionButton(
                    label: '返回首页',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
