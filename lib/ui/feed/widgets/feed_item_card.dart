import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/feed_article.dart';
import '../../../services/image_cache_manager.dart';
import '../text_explosion_sheet.dart';

/// 信息流里的单条卡片：左侧缩略图 + 右侧标题/摘要/元信息。
class FeedItemCard extends StatelessWidget {
  final FeedArticle article;
  final bool showThumb; // 是否显示缩略图（设置里可关）
  final bool isRead; // 是否已读：读过的标题变灰，和未读区分开
  final VoidCallback onTap;

  const FeedItemCard({
    super.key,
    required this.article,
    this.showThumb = true,
    this.isRead = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 扁平白色行样式：不再用 Card（无边框圆角、无阴影、无外边距），
    // 行与行之间的分隔交给列表页的 0.5px 分割线处理。
    // 这里套一层 Material 是为了给 InkWell 提供水波纹的"画布"，
    // 同时把行背景固定为白色（即使页面背景不是白色也能保持白底）。
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图：开关打开【且】文章确实带图时才画；
              // URL 为空就整体隐藏（不再画灰色占位框），让右侧文字区占满整行。
              if (showThumb && article.thumbUrl.isNotEmpty)
                _Thumb(url: article.thumbUrl),
              if (showThumb && article.thumbUrl.isNotEmpty)
                const SizedBox(width: 12),
              // 右侧文字区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题：支持「长按」触发文字大爆炸（分词 + 滑动选词加屏蔽词）。
                    // 普通点击仍由外层 InkWell 打开详情，两者不冲突。
                    GestureDetector(
                      // 让整块文字区域（含省略号区域）都能响应长按
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () =>
                          TextExplosionSheet.show(context, article.title),
                      child: Text(
                        article.title,
                        // 已读就把标题染灰，一眼区分"读过的"和"没读的"
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isRead ? Colors.grey : null,
                          fontWeight: FontWeight.normal, // 常规（非粗体）
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (article.summary?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        article.summary!,
                        // 已读时摘要也跟着变浅，整体灰度更统一
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isRead ? Colors.grey : null,
                          fontWeight: FontWeight.normal, // 常规（非粗体）
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _Meta(article: article, isRead: isRead),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 缩略图：有 URL 就异步加载，失败/为空显示占位图标。
class _Thumb extends StatelessWidget {
  final String url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    const size = 84.0;
    const radius = BorderRadius.all(Radius.circular(8));

    // 注意：本 widget 只在 URL 非空时被调用（FeedItemCard 已先判断非空），
    // 所以这里无需再处理空 URL，直接交给缓存图片组件加载即可。

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // 用自定义缓存管理器：保留天数由设置页配置（默认 2 天），
        // 不用默认的 DefaultCacheManager（它固定保留 30 天）
        cacheManager: FeedImageCacheManager.instance,
        // 占位：图片还没下载完时先画一个灰色圆角块占住位置。
        // （之前这里有个转圈圈，按需求去掉了 —— 单纯占位即可，不挡布局。）
        placeholder: (context, url) => const SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: radius,
            ),
          ),
        ),
        // 失败：占位图标
        errorWidget: (context, url, error) => const SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: radius,
            ),
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

/// 卡片底部元信息：作者 · 时间
class _Meta extends StatelessWidget {
  final FeedArticle article;
  final bool isRead;
  const _Meta({required this.article, this.isRead = false});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (article.author?.isNotEmpty == true) parts.add(article.author!);
    if (article.publishTime?.isNotEmpty == true)
      parts.add(article.publishTime!);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  ·  '),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        // 已读时元信息也淡一点；未读时保持原本的灰色
        color: isRead ? Colors.grey.shade400 : Colors.grey,
        fontWeight: FontWeight.normal, // 常规（非粗体）
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
