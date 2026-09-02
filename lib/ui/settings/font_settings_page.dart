import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/feed_settings_provider.dart';

/// 字体设置页（交互/样式参考微信的"字体大小"）。
///
/// 顶部一段预览文字，下面一个滑块——拖动时全 App 字号实时跟着变，
/// 因为字号是通过 [MyApp] 里的 TextScaler 全局生效的，这里只是改那个倍数。
class FontSettingsPage extends ConsumerWidget {
  const FontSettingsPage({super.key});

  /// 预设档位：倍数越小字越小。下标 0~4 对应滑块的 5 个停靠点。
  static const List<double> _presets = [0.85, 1.0, 1.15, 1.3, 1.45];
  static const List<String> _presetLabels = ['小', '标准', '大', '超大', '特大'];

  /// 根据当前倍数，找到它落在哪个预设档位（取最接近的，避免浮点误差导致找不到）。
  int _currentIndex(double scale) {
    var best = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < _presets.length; i++) {
      final diff = (_presets[i] - scale).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(feedSettingsProvider).fontScale;
    final index = _currentIndex(scale);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('字体设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // —— 预览区：直接拿真实的标题/摘要样式画一段示例，
          //    因为全局 TextScaler 已经把倍数作用上来，这里会随滑块实时变化。 ——
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '这是标题的预览效果', // 模拟信息流卡片标题
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '这是摘要的预览效果，字号也会跟随下面的滑块一起变化，',
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '正文预览：拖动下方滑块，可以看到整段文字、以及返回后信息流里'
                    '的标题与摘要都会按相同比例放大或缩小。设置对所有页面统一生效。',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // —— 滑块区：左小 A、右大 A，中间是档位滑块 ——
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('A', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(
                  value: index.toDouble(),
                  min: 0,
                  max: (_presets.length - 1).toDouble(),
                  divisions: _presets.length - 1,
                  label: _presetLabels[index],
                  onChanged: (v) {
                    // 滑块停在哪个档位，就把对应倍数写进设置（实时持久化 + 全局生效）
                    final i = v.round();
                    ref
                        .read(feedSettingsProvider.notifier)
                        .setFontScale(_presets[i]);
                  },
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 28)),
            ],
          ),
          // 档位文字提示：高亮当前档位，和微信一样给出"小/标准/大/超大/特大"
          Center(
            child: Text(
              '当前：${_presetLabels[index]}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '“标准”对应系统默认字号',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
