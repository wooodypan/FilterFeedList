import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/feed_article.dart';
import '../../../services/image_cache_manager.dart';
import '../text_explosion_sheet.dart';

/// "已读"文字用的暗色：在主题前景色基础上调透明到 45%。
///
/// 用主题色 + 透明度，而不是写死 Colors.grey —— 后者在深色模式下
/// （深底 + 中灰字）对比度不够，看着发虚。
Color _dimmed(ThemeData theme) =>
    theme.colorScheme.onSurface.withValues(alpha: 0.45);

/// 信息流里的单条卡片：左侧缩略图 + 右侧标题/摘要/元信息。
///
/// 三种手势，互不冲突：
/// - 整行单击 → 打开详情（[onTap]）
/// - 长按标题 → 文字大爆炸（分词加屏蔽词）
/// - 长按其它区域 → 弹菜单（[onRequestMenu]，列表页实现为「使用默认浏览器打开」）
///
/// 关键设计：**整张卡片只挂一个长按识别器**，按下后按坐标判断落在标题上还是别处，
/// 再决定走哪条分支。
/// 不能写成「卡片一个长按 + 标题嵌套一个长按」——那样两个同类型识别器会在
/// Flutter 手势竞技场里互相争抢，谁生效取决于注册顺序，行为不稳定。
class FeedItemCard extends StatefulWidget {
  final FeedArticle article;
  final bool showThumb; // 是否显示缩略图（设置里可关）
  final bool isRead; // 是否已读：读过的标题变灰，和未读区分开
  final VoidCallback onTap;

  /// 长按「标题以外」的区域时的回调，参数是手指按下的屏幕坐标
  /// （列表页用它把菜单弹在手指位置，符合直觉）。
  /// 不传就不弹菜单（但标题长按的文字大爆炸照常可用）。
  final void Function(Offset globalPosition)? onRequestMenu;

  const FeedItemCard({
    super.key,
    required this.article,
    this.showThumb = true,
    this.isRead = false,
    required this.onTap,
    this.onRequestMenu,
  });

  @override
  State<FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends State<FeedItemCard> {
  /// 标题组件的 key：长按发生时用它量出标题在屏幕上的矩形，
  /// 才能判断"手指是不是按在标题上"。
  /// 必须放在 State 里长期持有，不能在 build 里临时 new（那样每次重建都会
  /// 换来一个新 key，导致整个子树重建，列表滑动会掉帧）。
  final GlobalKey _titleKey = GlobalKey();

  /// 长按统一入口：先判断落点，再决定弹大爆炸还是弹菜单。
  void _onLongPressStart(LongPressStartDetails details) {
    if (_isOnTitle(details.globalPosition)) {
      // 按在标题上 → 文字大爆炸（分词选词加屏蔽词）
      TextExplosionSheet.show(context, widget.article.title);
      return;
    }
    // 按在别处 → 交给列表页弹菜单（「使用默认浏览器打开」）
    widget.onRequestMenu?.call(details.globalPosition);
  }

  /// 判断某个屏幕坐标是否落在标题区域内。
  ///
  /// 做法：用标题的 RenderBox 拿到它在屏幕上的矩形（localToGlobal），
  /// 再判断点是否在矩形内。横向向右放宽到卡片右边缘——标题经常只有几个字，
  /// 点在标题右边的空白也应该算"按在标题行上"，更好按。
  bool _isOnTitle(Offset globalPosition) {
    final titleBox = _titleKey.currentContext?.findRenderObject();
    if (titleBox is! RenderBox || !titleBox.attached) return false;

    final topLeft = titleBox.localToGlobal(Offset.zero);
    var rect = topLeft & titleBox.size;

    final cardBox = context.findRenderObject();
    if (cardBox is RenderBox && cardBox.attached) {
      final cardRight =
          (cardBox.localToGlobal(Offset.zero) & cardBox.size).right;
      rect = Rect.fromLTRB(rect.left, rect.top, cardRight, rect.bottom);
    }

    // 上下各放宽 4px：手指不一定那么精准，别让用户"明明按在标题上却弹了菜单"
    return rect.inflate(4).contains(globalPosition);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 扁平行样式：不再用 Card（无边框圆角、无阴影、无外边距），
    // 行与行之间的分隔交给列表页的 0.5px 分割线处理。
    // 背景用主题里的 surface（浅色模式下是白、深色模式下是深灰），
    // 【不要写死 Colors.white】——否则深色模式下这里会是一块刺眼的白条。
    return Material(
      color: theme.colorScheme.surface,
      // 点击和长按由同一个 GestureDetector 承担：
      // - onTap：单击打开详情
      // - onLongPressStart：长按，按落点决定弹大爆炸还是弹菜单
      // 两者是不同类型的手势识别器，Flutter 手势竞技场会自动区分：
      // 快速抬起 = 单击；按住超过约 500ms = 长按，此时单击被取消，不会两个都触发。
      // opaque = 空白区域也算命中，不必精准按在文字笔画上。
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: _onLongPressStart,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 缩略图：开关打开【且】文章确实带图时才画；
              // URL 为空就整体隐藏（不再画灰色占位框），让右侧文字区占满整行。
              if (widget.showThumb && widget.article.thumbUrl.isNotEmpty)
                _Thumb(url: widget.article.thumbUrl),
              if (widget.showThumb && widget.article.thumbUrl.isNotEmpty)
                const SizedBox(width: 12),
              // 右侧文字区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题：这里【不挂】手势，只用一个 key 标记位置。
                    // 长按是否落在标题上，统一由上面的 _onLongPressStart 判断，
                    // 这样"标题长按"和"整卡长按"就不会互相抢手势。
                    Text(
                      key: _titleKey,
                      widget.article.title,
                      // 已读就把标题调暗，一眼区分"读过的"和"没读的"。
                      // 用 onSurface.withValues(alpha:) 而不是写死 Colors.grey：
                      // 前者在深色模式下会自动变成"暗一点的白"，
                      // 写死灰色则可能在深底上看不清。
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: widget.isRead ? _dimmed(theme) : null,
                        fontWeight: FontWeight.normal, // 常规（非粗体）
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.article.summary?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.article.summary!,
                        // 已读时摘要也跟着变浅，整体灰度更统一
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: widget.isRead ? _dimmed(theme) : null,
                          fontWeight: FontWeight.normal, // 常规（非粗体）
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _Meta(article: widget.article, isRead: widget.isRead),
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

    // 占位块的颜色取自主题（浅色=浅灰、深色=深灰），
    // 写死 Colors.black12 的话深色模式下会和背景糊成一片。
    final placeholderColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;

    // 占位块：图片没下载完 / 下载失败时都用它占住位置，避免布局跳动
    Widget placeholder({Widget? child}) => SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: placeholderColor,
          borderRadius: radius,
        ),
        child: child,
      ),
    );

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
        placeholder: (context, url) => placeholder(),
        // 失败：占位图标
        errorWidget: (context, url, error) => placeholder(
          child: const Icon(Icons.broken_image, color: Colors.grey),
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
    final theme = Theme.of(context);
    final parts = <String>[];
    if (article.author?.isNotEmpty == true) parts.add(article.author!);
    if (article.publishTime?.isNotEmpty == true)
      parts.add(article.publishTime!);
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join('  ·  '),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        // 未读用主题的次要文字色（onSurfaceVariant），已读再调暗一档。
        // 不写死 Colors.grey：深色模式下灰色字在深底上会发虚。
        color: isRead ? _dimmed(theme) : theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.normal, // 常规（非粗体）
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
