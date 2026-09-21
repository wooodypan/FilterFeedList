import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/translation_mode.dart';
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

  /// 振动触感反馈：点击顶部数据源 Tab 切换时轻微振动一下（默认开启）。
  /// 纯体验增强，关掉后完全静默。
  final bool hapticFeedback;

  /// 翻译模式：数据源里打开了"翻译"开关的字段，译文是覆盖原文还是和原文一起显示。
  ///
  /// 默认 [TranslationMode.bilingual]（原文在上、译文在下）：译文可能有误差，
  /// 留着原文能对照着看，比直接替换掉原文更稳妥。
  final TranslationMode translationMode;

  /// 主题色：App 的主色调（默认青绿，和改造前写死的 Colors.teal 一致）。
  ///
  /// 它不是"某一个按钮的颜色"，而是交给 Material3 的 colorSchemeSeed：
  /// Flutter 会用这一个颜色自动推导出整套配色（主色、次要色、容器色、
  /// 各层级背景……），所以只改这一个值，全 App 的观感就跟着变。
  final Color themeColor;

  /// 外观模式（亮/暗）：跟随系统、强制浅色、强制深色。
  ///
  /// 默认 [ThemeMode.system]：系统切成深色时 App 自动跟着变，
  /// 用户不改设置也能享受到，是现在 App 的通行做法。
  final ThemeMode themeMode;

  const FeedSettings({
    this.aggregateMode = false,
    this.showThumb = true,
    this.fontScale = 1.0,
    this.imageCacheDays = FeedImageCacheManager.defaultDays,
    this.hapticFeedback = true,
    this.translationMode = TranslationMode.bilingual,
    this.themeColor = Colors.teal,
    this.themeMode = ThemeMode.system,
  });

  FeedSettings copyWith({
    bool? aggregateMode,
    bool? showThumb,
    double? fontScale,
    int? imageCacheDays,
    bool? hapticFeedback,
    TranslationMode? translationMode,
    Color? themeColor,
    ThemeMode? themeMode,
  }) {
    return FeedSettings(
      aggregateMode: aggregateMode ?? this.aggregateMode,
      showThumb: showThumb ?? this.showThumb,
      fontScale: fontScale ?? this.fontScale,
      imageCacheDays: imageCacheDays ?? this.imageCacheDays,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      translationMode: translationMode ?? this.translationMode,
      themeColor: themeColor ?? this.themeColor,
      themeMode: themeMode ?? this.themeMode,
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
  static const _kHapticFeedback = 'haptic_feedback';
  static const _kTranslationMode = 'translation_mode';
  static const _kThemeColor = 'theme_color';
  static const _kThemeMode = 'theme_mode';
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
      // 振动反馈默认开：老用户没存过这个 key，首次升级后也能享受新功能
      hapticFeedback: prefs.getBool(_kHapticFeedback) ?? true,
      // 翻译模式：存的是枚举下标（0=原文替换，1=双语共存）。
      // 老用户没存过 → 默认双语共存。
      translationMode: _decodeTranslationMode(prefs.getInt(_kTranslationMode)),
      // 主题色：存的是 Color 的整数值（0xAARRGGBB）。老版本没存过就用默认青绿。
      // 顺手把透明通道抹掉（强制不透明），避免异常数据导致整套配色发灰。
      themeColor: _decodeColor(prefs.getInt(_kThemeColor)),
      // 外观模式：存的是 0/1/2（对应 ThemeMode 的三个值）。
      // 老版本没存过 → 跟随系统。
      themeMode: _decodeThemeMode(prefs.getInt(_kThemeMode)),
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

  /// 开关振动触感反馈（立即生效，下次点 Tab 就按新值走）。
  Future<void> setHapticFeedback(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHapticFeedback, v);
    state = state.copyWith(hapticFeedback: v);
  }

  /// 设置翻译模式（原文替换 / 双语共存）。
  ///
  /// 注意：这里只负责改设置。已经拉下来的文章里装的还是按旧模式拼好的文字，
  /// 要看到新效果得让信息流重新拉取——这一步由设置页在改完之后主动作废
  /// 信息流 provider 来完成（见 settings_page.dart 的 _pickTranslationMode）。
  Future<void> setTranslationMode(TranslationMode v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTranslationMode, v.index);
    state = state.copyWith(translationMode: v);
  }

  /// 设置主题色（立即生效：[MyApp] 会把这个值作为 colorSchemeSeed 重建整套配色）。
  Future<void> setThemeColor(Color v) async {
    final prefs = await SharedPreferences.getInstance();
    // 只存整数值（0xAARRGGBB）；读取时再还原成 Color
    await prefs.setInt(_kThemeColor, v.toARGB32());
    state = state.copyWith(themeColor: v);
  }

  /// 设置外观模式（跟随系统 / 浅色 / 深色），立即生效。
  Future<void> setThemeMode(ThemeMode v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, v.index);
    state = state.copyWith(themeMode: v);
  }

  /// 一次性写入整份设置（导入备份时用：备份里的开关要整体还原，逐项 set 会多写好几次）。
  Future<void> apply(FeedSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAggregate, settings.aggregateMode);
    await prefs.setBool(_kShowThumb, settings.showThumb);
    await prefs.setDouble(_kFontScale, settings.fontScale);
    await prefs.setInt(_kImageCacheDays, settings.imageCacheDays);
    await prefs.setBool(_kHapticFeedback, settings.hapticFeedback);
    await prefs.setInt(_kTranslationMode, settings.translationMode.index);
    await prefs.setInt(_kThemeColor, settings.themeColor.toARGB32());
    await prefs.setInt(_kThemeMode, settings.themeMode.index);
    state = settings;
  }

  /// 把存进 SharedPreferences 的整数还原成 Color。
  ///
  /// 做了两件防御：
  /// - 没存过（null）或数值不合法 → 回落到默认青绿；
  /// - 强制不透明（把 alpha 位置成 0xFF）：半透明的主色会让文字/按钮对比度崩掉。
  static Color _decodeColor(int? value) {
    if (value == null) return Colors.teal;
    return Color(0xFF000000 | (value & 0x00FFFFFF));
  }

  /// 把存进 SharedPreferences 的整数还原成 [TranslationMode]。
  ///
  /// 和 [_decodeThemeMode] 一个套路：按下标显式映射，不用 `values[i]`，
  /// 免得以后枚举顺序调整（或加新值）后老数据被读成别的模式。
  /// 没存过（老用户）或数值不合法 → 双语共存。
  static TranslationMode _decodeTranslationMode(int? index) {
    switch (index) {
      case 0:
        return TranslationMode.replace;
      case 1:
        return TranslationMode.bilingual;
      default:
        return TranslationMode.bilingual;
    }
  }

  /// 把存进 SharedPreferences 的整数还原成 [ThemeMode]。
  ///
  /// 存的是 `ThemeMode.index`（system=0、light=1、dark=2），
  /// 但**不能直接写 `ThemeMode.values[i]`** —— 万一以后 Flutter 调整了
  /// 枚举顺序或加新值，老数据就会错位（比如把"深色"读成"浅色"）。
  /// 所以这里显式按 index 映射，并给非法值兜底成"跟随系统"。
  static ThemeMode _decodeThemeMode(int? index) {
    switch (index) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      case 0:
        return ThemeMode.system;
      default:
        // 没存过（老用户）或数值不合法 → 跟随系统，最安全的默认
        return ThemeMode.system;
    }
  }
}
