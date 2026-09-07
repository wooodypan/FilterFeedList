import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/feed_settings_provider.dart';

/// 主题色设置页。
///
/// 结构从上到下：
/// 1. 实时预览卡片（直接读当前 Theme 的 ColorScheme，改色后立刻变）
/// 2. 预设色板（12 个常见色，点一下就换）
/// 3. 自定义取色器（HSV：一条色相条 + 一块"饱和度 / 明度"面板）
///
/// 选中的颜色统一写进 [feedSettingsProvider]，
/// [MyApp] 再把它作为 colorSchemeSeed 生成整套配色，全 App 生效。
class ThemeColorPage extends ConsumerWidget {
  const ThemeColorPage({super.key});

  /// 预设主题色（Material 标准色，覆盖常见色系）。
  /// 第一个是默认色，和改造前写死的 Colors.teal 保持一致。
  static const List<Color> _presets = <Color>[
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.red,
    Colors.deepOrange,
    Colors.orange,
    Colors.amber,
    Colors.green,
    Colors.lightBlue,
    Colors.brown,
  ];

  /// 与 _presets 一一对应的中文名，选中时展示。
  static const List<String> _presetNames = <String>[
    '青绿',
    '蓝色',
    '靛蓝',
    '紫色',
    '粉色',
    '红色',
    '深橙',
    '橙色',
    '琥珀',
    '绿色',
    '天蓝',
    '棕色',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(feedSettingsProvider).themeColor;
    final theme = Theme.of(context);
    // 当前颜色是否正好是某个预设色（不是就说明用户用了自定义色）
    final presetIndex = _presets.indexWhere(
      (c) => c.toARGB32() == current.toARGB32(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('主题色')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _PreviewCard(),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('预设颜色', style: theme.textTheme.titleSmall),
              const Spacer(),
              // 当前预设名；自定义色时显示"自定义"
              Text(
                presetIndex >= 0 ? _presetNames[presetIndex] : '自定义',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PresetGrid(
            presets: _presets,
            names: _presetNames,
            current: current,
            onPick: (color) =>
                ref.read(feedSettingsProvider.notifier).setThemeColor(color),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('自定义颜色', style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref
                    .read(feedSettingsProvider.notifier)
                    .setThemeColor(Colors.teal),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('恢复默认'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _HsvColorPicker(
            color: current,
            onChanged: (color) =>
                ref.read(feedSettingsProvider.notifier).setThemeColor(color),
          ),
          const SizedBox(height: 8),
          Text(
            '提示：这里选的是"种子色"，Flutter 会用它自动推导出主色、'
            '次要色、卡片背景等一整套配色，不需要逐个调。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 实时预览卡片：用当前主题的 ColorScheme 画一小段界面。
///
/// 因为它就是普通 widget，主题一变（provider 更新 → MyApp 重建 ThemeData）
/// 它会自动跟着重绘，所以用户拖动取色器时能看到"所见即所得"的效果。
class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 模拟顶栏：主色底 + 主色之上的文字色
          Container(
            color: scheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              '漏斗阅读',
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '这是列表标题的预览效果',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '正文与次要文字保持中性色，只有强调元素跟随主题色。',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                // 三个典型的"跟主题色走"的控件
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('主要按钮')),
                    OutlinedButton(onPressed: () {}, child: const Text('次要按钮')),
                    Chip(
                      avatar: Icon(
                        Icons.check,
                        size: 16,
                        color: scheme.primary,
                      ),
                      label: const Text('选中标签'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 进度条也用主色，方便看清颜色变化
                LinearProgressIndicator(value: 0.7),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 预设色板：一行排不下的自动换行（用 Wrap，避免嵌套 GridView 的高度计算问题）。
class _PresetGrid extends StatelessWidget {
  final List<Color> presets;
  final List<String> names;
  final Color current;
  final ValueChanged<Color> onPick;

  const _PresetGrid({
    required this.presets,
    required this.names,
    required this.current,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < presets.length; i++)
          _Swatch(
            color: presets[i],
            name: names[i],
            selected: current.toARGB32() == presets[i].toARGB32(),
            onTap: () => onPick(presets[i]),
          ),
      ],
    );
  }
}

/// 单个色块：圆形色块 + 下面的颜色名，选中时放大并打勾。
class _Swatch extends StatelessWidget {
  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 底色浅就用黑色勾，底色深就用白色勾，保证看得清（琥珀色尤其明显）
    final isLight =
        ThemeData.estimateBrightnessForColor(color) == Brightness.light;
    final checkColor = isLight ? Colors.black87 : Colors.white;

    return SizedBox(
      width: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: selected ? 52 : 44,
              height: selected ? 52 : 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  // 选中时描边加粗并用主色，未选中只给一条浅灰边（白底上也能看清）
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black12,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, color: checkColor, size: 26)
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// HSV 取色器（自己实现，不引第三方库）。
///
/// HSV 比 RGB 好调：
/// - H 色相 = 什么颜色（红/黄/蓝……），用一条彩虹条选
/// - S 饱和度 = 颜色浓不浓，横轴（左灰右艳）
/// - V 明度 = 亮不亮，纵轴（上亮下暗）
///
/// 实现上没有任何"魔法"：饱和度面板就是两层渐变叠出来的——
/// 底层「白 → 该色相的纯色」，上层「透明 → 黑」，
/// 用 GestureDetector 读手指坐标反算 S / V 即可。
class _HsvColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _HsvColorPicker({required this.color, required this.onChanged});

  @override
  State<_HsvColorPicker> createState() => _HsvColorPickerState();
}

class _HsvColorPickerState extends State<_HsvColorPicker> {
  late HSVColor _hsv;

  /// 最近一次由本组件自己回调出去的颜色。
  /// 用来区分"颜色是我拖出来的"还是"外部（预设色板）改的"，
  /// 避免拖拽过程中被回写、把手势打断。
  Color? _lastEmitted;

  /// 色相条的渐变色：HSV 的 6 个主色相（0° 红 → 360° 回到红）
  static const List<Color> _hueColors = <Color>[
    Color(0xFFFF0000), // 0°   红
    Color(0xFFFFFF00), // 60°  黄
    Color(0xFF00FF00), // 120° 绿
    Color(0xFF00FFFF), // 180° 青
    Color(0xFF0000FF), // 240° 蓝
    Color(0xFFFF00FF), // 300° 品红
    Color(0xFFFF0000), // 360° 红（闭合）
  ];

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant _HsvColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有"外部改了颜色"才同步进来（比如点了预设色板）；
    // 自己拖拽产生的回调直接忽略，否则正在拖的手势会被重置。
    if (widget.color != _lastEmitted) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  /// 统一出口：更新内部状态 + 通知外部。
  void _emit(HSVColor hsv) {
    setState(() => _hsv = hsv);
    final color = hsv.toColor();
    _lastEmitted = color;
    widget.onChanged(color);
  }

  /// 把手指在面板上的坐标换算成"饱和度 + 明度"。
  void _updateFromPanel(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    // 纵轴：上边是明度 1（最亮），下边是明度 0（全黑），所以要用 1 减
    final v = 1.0 - (local.dy / size.height).clamp(0.0, 1.0);
    _emit(_hsv.withSaturation(s).withValue(v));
  }

  /// 把手指在色相条上的横坐标换算成 0~360 的色相角。
  void _updateHue(double ratio) {
    _emit(_hsv.withHue(ratio.clamp(0.0, 1.0) * 360));
  }

  @override
  Widget build(BuildContext context) {
    // 当前色相的纯色（饱和度 1、明度 1），用来画面板底层渐变
    final pureHue = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // —— 饱和度 / 明度 面板 ——
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(
              constraints.maxWidth,
              constraints.maxWidth * 0.62,
            );
            return SizedBox(
              width: size.width,
              height: size.height,
              child: GestureDetector(
                // opaque：面板里没有真正的可点击 child，必须显式声明"整块区域都能接收手势"，
                // 否则默认行为（deferToChild）会因为子 widget 不响应而收不到拖动事件。
                behavior: HitTestBehavior.opaque,
                // 按下和拖动都能取色（onPanDown + onPanUpdate 覆盖全部场景）
                onPanDown: (d) => _updateFromPanel(d.localPosition, size),
                onPanUpdate: (d) => _updateFromPanel(d.localPosition, size),
                child: Stack(
                  children: [
                    // 底层：左白 → 右纯色（横向 = 饱和度）
                    // 用 Positioned.fill 撑满：DecoratedBox 没有 child 时
                    // 在 Stack 的 loose 约束下会缩成 0×0，渐变就看不见了。
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: <Color>[Colors.white, pureHue],
                          ),
                        ),
                      ),
                    ),
                    // 上层：上透明 → 下黑（纵向 = 明度）
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[Colors.transparent, Colors.black],
                          ),
                        ),
                      ),
                    ),
                    // 取色圈：位置由当前 S / V 反算
                    Positioned(
                      left: (_hsv.saturation * size.width - 12).clamp(
                        0.0,
                        size.width - 24,
                      ),
                      top: ((1 - _hsv.value) * size.height - 12).clamp(
                        0.0,
                        size.height - 24,
                      ),
                      child: _PickerThumb(color: _hsv.toColor()),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // —— 色相条 ——
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 32,
              child: GestureDetector(
                // 同上：整条色相条都要能拖，不能只在滑块的 24px 上生效
                behavior: HitTestBehavior.opaque,
                onPanDown: (d) => _updateHue(d.localPosition.dx / width),
                onPanUpdate: (d) => _updateHue(d.localPosition.dx / width),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(colors: _hueColors),
                        ),
                      ),
                    ),
                    Positioned(
                      left: ((_hsv.hue / 360) * width - 14).clamp(
                        0.0,
                        width - 28,
                      ),
                      top: 2,
                      child: _PickerThumb(
                        color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 取色器上的指示圈：白边 + 细投影，保证在任何底色上都看得见。
class _PickerThumb extends StatelessWidget {
  final Color color;

  const _PickerThumb({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 3),
        ],
      ),
    );
  }
}
