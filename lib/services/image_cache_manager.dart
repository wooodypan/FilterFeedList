import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 信息流图片的缓存管理器（替代 cached_network_image 默认的 DefaultCacheManager）。
///
/// 与默认实现的唯一区别：缓存保留天数（stalePeriod，默认实现是 30 天）可由
/// 用户在设置里配置，默认 2 天。超过天数没被再次访问的图片文件会被自动清理。
///
/// 注意生效时机：flutter_cache_manager 的过期清理发生在管理器创建时
/// （即每次启动后不久），所以改了保留天数要重启 App 才按新天数清理。
///
/// 用法：CachedNetworkImage(cacheManager: FeedImageCacheManager.instance, ...)。
class FeedImageCacheManager extends CacheManager {
  /// 缓存实例的唯一 key（一个 key 一套缓存目录，勿与其它缓存混用）
  static const _cacheKey = 'feedImageCache';

  /// 保留天数在 SharedPreferences 里的 key（设置页读写的是同一个 key，
  /// 两边共用这个常量，避免字符串写两份以后对不上）
  static const kImageCacheDaysPrefKey = 'image_cache_days';

  /// 设置页可选的保留天数列表
  static const List<int> kImageCacheDayOptions = [1, 2, 3, 7, 14, 30];

  /// 默认保留 2 天（用户需求：图片缓存只保留 2 天）
  static const int defaultDays = 2;

  FeedImageCacheManager._(super.config);

  static FeedImageCacheManager? _instance;

  /// 全局唯一实例。main() 里会先 await init()；
  /// 万一没初始化就被用到（理论上不会），兜底按默认 2 天建一个。
  static FeedImageCacheManager get instance =>
      _instance ??= FeedImageCacheManager._(_buildConfig(defaultDays));

  /// 启动时初始化：从 SharedPreferences 读用户配置的保留天数。
  /// 过期清理随这次创建被调度，超期文件会在启动后不久被自动删除。
  static Future<void> init() async {
    if (_instance != null) return;
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt(kImageCacheDaysPrefKey) ?? defaultDays;
    _instance = FeedImageCacheManager._(_buildConfig(days));
  }

  /// 按指定天数构造缓存配置
  static Config _buildConfig(int days) => Config(
    _cacheKey,
    // 最多保留 1000 个图片文件：天数没到但磁盘被撑爆时也能兜底清理
    maxNrOfCacheObjects: 1000,
    // 核心：超过 [days] 天没被访问过的图片自动删除
    stalePeriod: Duration(days: days),
  );
}
