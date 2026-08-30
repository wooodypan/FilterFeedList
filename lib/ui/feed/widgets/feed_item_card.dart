import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/feed_article.dart';
import '../text_explosion_sheet.dart';

/// 信息流里的单条卡片：左侧缩略图 + 右侧标题/摘要/元信息。
class FeedItemCard extends StatelessWidget {
  final FeedArticle article;
  final bool showThumb; // 是否显示缩略图（设置里可关）
  final VoidCallback onTap;

  const FeedItemCard({
    super.key,
    required this.article,
    this.showThumb = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (article.summary?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        article.summary!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _Meta(article: article),
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
        // 占位：加载中转圈
        placeholder: (context, url) => const SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: radius,
            ),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
  const _Meta({required this.article});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (article.author?.isNotEmpty == true) parts.add(article.author!);
    if (article.publishTime?.isNotEmpty == true)
      parts.add(article.publishTime!);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  ·  '),
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: Colors.grey),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
