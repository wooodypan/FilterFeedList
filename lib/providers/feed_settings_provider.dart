import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/image_cache_manager.dart';

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

  /// 图片缓存保留天数：超过 N 天没被访问的图片文件自动清理（默认 2 天）。
  /// 真正执行清理的是 FeedImageCacheManager，这里只是"用户改了什么"的记录，
  /// 改完要重启 App 才按新天数清理（清理发生在启动时）。
  final int imageCacheDays;

  const FeedSettings({
    this.aggregateMode = false,
    this.showThumb = true,
    this.fontScale = 1.0,
    this.imageCacheDays = FeedImageCacheManager.defaultDays,
  });

  FeedSettings copyWith({
    bool? aggregateMode,
    bool? showThumb,
    double? fontScale,
    int? imageCacheDays,
  }) {
    return FeedSettings(
      aggregateMode: aggregateMode ?? this.aggregateMode,
      showThumb: showThumb ?? this.showThumb,
      fontScale: fontScale ?? this.fontScale,
      imageCacheDays: imageCacheDays ?? this.imageCacheDays,
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
  // 图片缓存天数的 key 直接用缓存管理器里定义的常量，两边共用一份
  static const _kImageCacheDays = FeedImageCacheManager.kImageCacheDaysPrefKey;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = FeedSettings(
      aggregateMode: prefs.getBool(_kAggregate) ?? false,
      showThumb: prefs.getBool(_kShowThumb) ?? true,
      // 没有存过就用 1.0（标准大小），避免首次启动拿到 null 撑爆 UI
      fontScale: prefs.getDouble(_kFontScale) ?? 1.0,
      imageCacheDays:
          prefs.getInt(_kImageCacheDays) ?? FeedImageCacheManager.defaultDays,
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

  /// 设置图片缓存保留天数（写进 SharedPreferences；真正的清理
  /// 由 FeedImageCacheManager 在下次启动时按新天数执行）。
  Future<void> setImageCacheDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kImageCacheDays, days);
    state = state.copyWith(imageCacheDays: days);
  }

  /// 一次性写入整份设置（导入备份时用：备份里的开关要整体还原，逐项 set 会多写好几次）。
  Future<void> apply(FeedSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAggregate, settings.aggregateMode);
    await prefs.setBool(_kShowThumb, settings.showThumb);
    await prefs.setDouble(_kFontScale, settings.fontScale);
    await prefs.setInt(_kImageCacheDays, settings.imageCacheDays);
    state = settings;
  }
}
