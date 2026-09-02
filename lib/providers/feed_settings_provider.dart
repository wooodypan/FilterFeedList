import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局阅读设置。
class FeedSettings {
  /// 聚合模式：true = 所有启用源混进一条流；false = 每个源一个 Tab
  final bool aggregateMode;

  /// 是否显示缩略图（关掉更省流量）
  final bool showThumb;

  /// 字体缩放倍数：1.0 = 标准大小；>1 放大，<1 缩小。
  /// 全 App 的文字（列表标题、正文、设置页……）都按这个倍数统一缩放，
  /// 实现方式和微信一致——改一处、全局生效。
  final double fontScale;

  const FeedSettings({
    this.aggregateMode = false,
    this.showThumb = true,
    this.fontScale = 1.0,
  });

  FeedSettings copyWith({
    bool? aggregateMode,
    bool? showThumb,
    double? fontScale,
  }) {
    return FeedSettings(
      aggregateMode: aggregateMode ?? this.aggregateMode,
      showThumb: showThumb ?? this.showThumb,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}

/// 全局设置状态（用 SharedPreferences 持久化开关类选项）。
final feedSettingsProvider =
    StateNotifierProvider<FeedSettingsNotifier, FeedSettings>(
      (ref) => FeedSettingsNotifier(),
    );

class FeedSettingsNotifier extends StateNotifier<FeedSettings> {
  FeedSettingsNotifier() : super(const FeedSettings()) {
    _load();
  }

  static const _kAggregate = 'aggregate_mode';
  static const _kShowThumb = 'show_thumb';
  static const _kFontScale = 'font_scale';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = FeedSettings(
      aggregateMode: prefs.getBool(_kAggregate) ?? false,
      showThumb: prefs.getBool(_kShowThumb) ?? true,
      // 没有存过就用 1.0（标准大小），避免首次启动拿到 null 撑爆 UI
      fontScale: prefs.getDouble(_kFontScale) ?? 1.0,
    );
  }

  Future<void> setAggregateMode(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAggregate, v);
    state = state.copyWith(aggregateMode: v);
  }

  Future<void> setShowThumb(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowThumb, v);
    state = state.copyWith(showThumb: v);
  }

  /// 设置字体缩放倍数（实时生效：UI 通过 TextScaler 全局应用）。
  Future<void> setFontScale(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontScale, v);
    state = state.copyWith(fontScale: v);
  }

  /// 一次性写入整份设置（导入备份时用：备份里的开关要整体还原，逐项 set 会多写好几次）。
  Future<void> apply(FeedSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAggregate, settings.aggregateMode);
    await prefs.setBool(_kShowThumb, settings.showThumb);
    await prefs.setDouble(_kFontScale, settings.fontScale);
    state = settings;
  }
}
