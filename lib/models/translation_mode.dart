/// 翻译结果的展示方式（全局设置，入口在设置页的「翻译模式」）。
///
/// 数据源编辑页里给"标题""摘要"各有一个"翻译"开关，开关只决定**翻不翻**；
/// 翻出来的译文怎么放进字段里，由这里的模式统一决定，两者是正交的：
/// - 开关：某个数据源的某个字段要不要翻译（跟着数据源走，存进数据源配置）
/// - 模式：译文是覆盖原文还是和原文一起显示（全局，所有数据源共用）
enum TranslationMode {
  /// 原文替换：字段里只留译文，原文不再显示。
  replace,

  /// 双语共存：原文在上、译文在下，中间用一个换行符隔开。
  bilingual;

  /// 按当前模式，把一条原文 [original] 和它的译文 [translated] 拼成最终要展示的文字。
  ///
  /// 两种"没必要拼"的情况直接返回原文，避免界面上出现重复内容或空行：
  /// - 译文为空：翻译接口失败（此时 [translator] 会回退成空串），或者原文本身是空的；
  /// - 译文和原文一模一样：原文本来就是中文时，Google 会原样返回，拼起来会变成两行一样的字。
  String combine(String original, String translated) {
    final t = translated.trim();
    if (t.isEmpty || t == original.trim()) return original;
    // 双语共存用 '\n' 拼：列表卡片里的 Text 本来就支持换行，天然就是"上原文下译文"
    return this == TranslationMode.replace ? t : '$original\n$t';
  }
}
