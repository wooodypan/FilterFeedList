import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局阅读设置。
class FeedSettings {
  /// 聚合模式：true = 所有启用源混进一条流；false = 每个源一个 Tab
  final bool aggregateMode;

  /// 是否显示缩略图（关掉更省流量）
  final bool showThumb;

  const FeedSettings({this.aggregateMode = false, this.showThumb = true});

  FeedSettings copyWith({bool? aggregateMode, bool? showThumb}) {
    return FeedSettings(
      aggregateMode: aggregateMode ?? this.aggregateMode,
      showThumb: showThumb ?? this.showThumb,
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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = FeedSettings(
      aggregateMode: prefs.getBool(_kAggregate) ?? false,
      showThumb: prefs.getBool(_kShowThumb) ?? true,
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
}
