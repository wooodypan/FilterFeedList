import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/data_source_config.dart';
import '../../models/feed_article.dart';
import '../../models/field_mapping.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_source_provider.dart';
import '../../utils/validators.dart';

/// 数据源配置 / 编辑页。
///
/// 这是整个 app 最关键的交互：用户在这里填一份"字段映射规则"就能接入任意 API，
/// 不用写代码。底部还有"测试连接"按钮，填完立即验证映射对不对。
class DataSourceEditPage extends ConsumerStatefulWidget {
  /// 编辑时传入已存在的配置；新增时为 null
  final DataSourceConfig? initial;

  const DataSourceEditPage({super.key, this.initial});

  @override
  ConsumerState<DataSourceEditPage> createState() => _DataSourceEditPageState();
}

class _DataSourceEditPageState extends ConsumerState<DataSourceEditPage> {
  final _formKey = GlobalKey<FormState>();

  // 基础文本字段控制器
  final _nameC = TextEditingController();
  final _apiUrlC = TextEditingController();
  final _listPathC = TextEditingController();
  final _titlePathC = TextEditingController();
  final _thumbPathC = TextEditingController();
  final _summaryPathC = TextEditingController();
  final _authorPathC = TextEditingController();
  final _publishTimeC = TextEditingController();
  final _detailUrlPathC = TextEditingController();
  final _contentPathC = TextEditingController();

  // 请求方式（GET/POST）
  String _method = 'GET';

  // 详情渲染模式
  DetailRenderMode _detailMode = DetailRenderMode.webview;

  // 是否启用"App 深链直达"（默认开启）
  bool _useAppDeepLink = true;

  // 标题字段取到的原文，是否要翻成中文
  bool _translateTitle = false;

  // 摘要字段（summaryPath 取到的那段文字）是否要翻成中文。
  // 注意它翻的是 summaryPath 指向的内容，不一定是 summary 字段本身：
  // summaryPath 填 title 时，打开这个开关就是"把标题翻成中文，译文放进摘要"。
  bool _translateSummary = false;

  // 动态 key-value 列表（headers / queryParams）
  final List<_KvRow> _headers = [];
  final List<_KvRow> _queryParams = [];

  // 测试预览结果
  List<FeedArticle>? _preview;
  String? _previewError;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _prefillFromInitial();
  }

  /// 如果是编辑模式，把已有配置填进表单
  void _prefillFromInitial() {
    final c = widget.initial;
    if (c == null) return;
    _nameC.text = c.name;
    _apiUrlC.text = c.apiUrl;
    _method = c.method;
    _detailMode = c.detailMode;
    _useAppDeepLink = c.useAppDeepLink;
    // RSS 源没有字段映射（本页也只编辑 JSONPath 源），可空时跳过这部分
    final m = c.fieldMapping;
    if (m != null) {
      _listPathC.text = m.listPath;
      _titlePathC.text = m.titlePath;
      _thumbPathC.text = m.thumbPath;
      _summaryPathC.text = m.summaryPath ?? '';
      _authorPathC.text = m.authorPath ?? '';
      _publishTimeC.text = m.publishTimePath ?? '';
      _detailUrlPathC.text = m.detailUrlPath ?? '';
      _contentPathC.text = m.contentPath ?? '';
      _translateTitle = m.translateTitle;
      _translateSummary = m.translateSummary;
    }
    c.headers?.forEach((k, v) => _headers.add(_KvRow(k, v)));
    c.queryParams?.forEach((k, v) => _queryParams.add(_KvRow(k, v)));
  }

  @override
  void dispose() {
    // 释放所有控制器，避免内存泄漏
    for (final c in [
      _nameC,
      _apiUrlC,
      _listPathC,
      _titlePathC,
      _thumbPathC,
      _summaryPathC,
      _authorPathC,
      _publishTimeC,
      _detailUrlPathC,
      _contentPathC,
    ]) {
      c.dispose();
    }
    for (final row in [..._headers, ..._queryParams]) {
      row.dispose();
    }
    super.dispose();
  }

  /// 把表单组装成一份 DataSourceConfig（测试 / 保存共用）
  DataSourceConfig _buildConfig({required String id}) {
    final mapping = FieldMapping(
      listPath: _listPathC.text.trim(),
      titlePath: _titlePathC.text.trim(),
      thumbPath: _thumbPathC.text.trim(),
      summaryPath: _opt(_summaryPathC.text),
      authorPath: _opt(_authorPathC.text),
      publishTimePath: _opt(_publishTimeC.text),
      detailUrlPath: _detailMode == DetailRenderMode.webview
          ? _opt(_detailUrlPathC.text)
          : null,
      contentPath: _detailMode == DetailRenderMode.native
          ? _opt(_contentPathC.text)
          : null,
      // 两个"是否翻译"开关：只记录"翻不翻"，译文怎么展示由全局翻译模式决定
      translateTitle: _translateTitle,
      translateSummary: _translateSummary,
    );

    return DataSourceConfig(
      id: id,
      name: _nameC.text.trim(),
      apiUrl: _apiUrlC.text.trim(),
      method: _method,
      headers: _collectMap(_headers),
      queryParams: _collectMap(_queryParams),
      fieldMapping: mapping,
      detailMode: _detailMode,
      useAppDeepLink: _useAppDeepLink,
    );
  }

  /// 把空字符串转成 null（可选字段留空就不写进配置）
  static String? _opt(String v) => v.trim().isEmpty ? null : v.trim();

  /// 收集动态 key-value 列表成 Map（过滤掉 key 为空的行）
  Map<String, String>? _collectMap(List<_KvRow> rows) {
    final map = <String, String>{};
    for (final r in rows) {
      final k = r.key.text.trim();
      final v = r.value.text; // value 允许为空
      if (k.isNotEmpty) map[k] = v;
    }
    return map.isEmpty ? null : map;
  }

  /// 校验表单（含条件必填）
  bool _validate() {
    // detailUrlPath 在 webview 模式下必填；contentPath 在 native 模式下必填
    if (_detailMode == DetailRenderMode.webview) {
      if (_detailUrlPathC.text.trim().isEmpty) {
        _showMsg('WebView 模式下"详情链接字段"必填');
        return false;
      }
    } else {
      if (_contentPathC.text.trim().isEmpty) {
        _showMsg('原生渲染模式下"正文字段"必填');
        return false;
      }
    }
    return _formKey.currentState?.validate() ?? false;
  }

  /// 测试连接：立即请求一次并解析，展示前 3 条预览
  Future<void> _testConnection() async {
    if (!_validate()) return;
    setState(() {
      _testing = true;
      _preview = null;
      _previewError = null;
    });
    final temp = _buildConfig(id: 'preview');
    try {
      final articles = await ref
          .read(feedRepositoryProvider)
          .fetchFeed(temp, page: 1);
      setState(() {
        _preview = articles.take(3).toList();
      });
    } catch (e) {
      setState(() {
        _previewError = e.toString();
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  /// 保存配置
  Future<void> _save() async {
    if (!_validate()) return;
    final id =
        widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final config = _buildConfig(id: id);
    await ref.read(dataSourcesProvider.notifier).upsert(config);
    if (mounted) {
      _showMsg('已保存');
      context.pop(); // 返回列表页
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? '新增数据源' : '编辑数据源'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _textField(_nameC, '数据源名称', required: true),
              _textField(
                _apiUrlC,
                'API 地址（支持 {page}/{pageSize} 占位符）',
                required: true,
                validator: Validators.requiredUrl,
                hint: 'https://example.com/api/list?page={page}',
              ),
              // 请求方式
              DropdownButtonFormField<String>(
                value: _method,
                decoration: const InputDecoration(labelText: '请求方式'),
                items: const [
                  DropdownMenuItem(value: 'GET', child: Text('GET')),
                  DropdownMenuItem(value: 'POST', child: Text('POST')),
                ],
                onChanged: (v) => setState(() => _method = v ?? 'GET'),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                '字段映射（核心）',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              _textField(
                _listPathC,
                'listPath（定位数组，如 data.list）',
                required: true,
                validator: Validators.jsonPath,
              ),
              // 标题、摘要这两个字段支持"顺手翻译"：
              // 打开右边开关后，取到的原文会被翻成中文，再按设置页选的翻译模式
              // 决定是"替换原文"还是"原文在上、译文在下"。
              _translatableField(
                _titlePathC,
                'titlePath（标题，如 title）',
                required: true,
                validator: Validators.jsonPath,
                translate: _translateTitle,
                onTranslateChanged: (v) => setState(() => _translateTitle = v),
              ),
              _textField(
                _thumbPathC,
                'thumbPath（缩略图，如 thumb 或 images[0]）',
                required: true,
                validator: Validators.jsonPath,
              ),
              _translatableField(
                _summaryPathC,
                'summaryPath（摘要，选填）',
                validator: Validators.jsonPath,
                translate: _translateSummary,
                onTranslateChanged: (v) =>
                    setState(() => _translateSummary = v),
              ),
              _textField(
                _authorPathC,
                'authorPath（作者，选填）',
                validator: Validators.jsonPath,
              ),
              _textField(
                _publishTimeC,
                'publishTimePath（时间，选填）',
                validator: Validators.jsonPath,
              ),
              const Divider(),
              // 详情渲染模式
              const Text(
                '详情页渲染方式',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              RadioListTile<DetailRenderMode>(
                title: const Text('WebView（加载详情链接）'),
                value: DetailRenderMode.webview,
                groupValue: _detailMode,
                onChanged: (v) => setState(() => _detailMode = v!),
              ),
              RadioListTile<DetailRenderMode>(
                title: const Text('原生渲染（渲染正文 HTML）'),
                value: DetailRenderMode.native,
                groupValue: _detailMode,
                onChanged: (v) => setState(() => _detailMode = v!),
              ),
              if (_detailMode == DetailRenderMode.webview)
                _textField(
                  _detailUrlPathC,
                  'detailUrlPath（详情链接字段，如 url）',
                  validator: Validators.jsonPath,
                ),
              if (_detailMode == DetailRenderMode.native)
                _textField(
                  _contentPathC,
                  'contentPath（正文字段，如 content）',
                  validator: Validators.jsonPath,
                ),
              const Divider(),
              // App 深链直达开关：开启后，若数据源产出的文章带 appDeepLink
              // （如 smzdm://youhui/123），点开时优先拉起对应 App，拉起失败再退回 WebView。
              SwitchListTile(
                title: const Text('使用 AppDeepLink 直达 App'),
                subtitle: const Text('开启后优先用文章的深链拉起对应 App'),
                value: _useAppDeepLink,
                onChanged: (v) => setState(() => _useAppDeepLink = v),
              ),
              const Divider(),
              // 动态 headers
              _KvEditor(
                title: '请求头 Headers（选填，有些 API 需要 token）',
                rows: _headers,
                onAdd: () => setState(() => _headers.add(_KvRow())),
                onRemove: (i) => setState(() {
                  _headers[i].dispose();
                  _headers.removeAt(i);
                }),
              ),
              const SizedBox(height: 12),
              // 动态 queryParams
              _KvEditor(
                title: '静态 Query 参数（选填）',
                rows: _queryParams,
                onAdd: () => setState(() => _queryParams.add(_KvRow())),
                onRemove: (i) => setState(() {
                  _queryParams[i].dispose();
                  _queryParams.removeAt(i);
                }),
              ),
              const SizedBox(height: 20),
              // 测试连接按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_testing ? '测试中…' : '测试连接并预览'),
                ),
              ),
              // 预览结果
              _PreviewSection(preview: _preview, error: _previewError),
            ],
          ),
        ),
      ),
    );
  }

  /// 通用文本输入框
  Widget _textField(
    TextEditingController c,
    String label, {
    bool required = false,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator:
            validator ??
            (required
                ? (v) => v == null || v.trim().isEmpty ? '该项必填' : null
                : null),
      ),
    );
  }

  /// 带"翻译"开关的字段输入框：左边是原来的路径输入框，右边竖排一个开关。
  ///
  /// 开关只表示"这个字段取到的原文要不要翻译"，译文怎么展示（替换原文 / 双语共存）
  /// 由设置页的「翻译模式」统一决定，所以这里不用再选语言、选模式。
  Widget _translatableField(
    TextEditingController c,
    String label, {
    required bool translate,
    required ValueChanged<bool> onTranslateChanged,
    bool required = false,
    String? Function(String?)? validator,
  }) {
    return Row(
      // 顶部对齐：开关和输入框都从第一行开始排，看起来才不会一高一低
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 输入框吃掉剩余宽度，窄屏也不会把开关挤出去
        Expanded(
          child: _textField(c, label, required: required, validator: validator),
        ),
        Padding(
          // 左边留一点缝，顶部往下挪几像素跟输入框里的文字对齐
          padding: const EdgeInsets.only(left: 4, top: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                // 开关本体只有 40 多像素高，缩一缩省点横向空间
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: translate,
                onChanged: onTranslateChanged,
              ),
              Text('翻译', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// 动态 key-value 的一行（header / query 共用）
class _KvRow {
  final TextEditingController key = TextEditingController();
  final TextEditingController value = TextEditingController();

  _KvRow([String? k, String? v]) {
    if (k != null) key.text = k;
    if (v != null) value.text = v;
  }

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

/// 动态 key-value 编辑器（可增删行）
class _KvEditor extends StatelessWidget {
  final String title;
  final List<_KvRow> rows;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _KvEditor({
    required this.title,
    required this.rows,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final row = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.key,
                    decoration: const InputDecoration(
                      hintText: 'key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: row.value,
                    decoration: const InputDecoration(
                      hintText: 'value',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('添加一行'),
        ),
      ],
    );
  }
}

/// 测试预览区：成功显示前 3 条，失败显示具体错误
class _PreviewSection extends StatelessWidget {
  final List<FeedArticle>? preview;
  final String? error;

  const _PreviewSection({this.preview, this.error});

  @override
  Widget build(BuildContext context) {
    // 提示块配色走主题的 errorContainer / 固定绿色容器：
    // 写死 red.shade50 这类浅色底在深色模式下会变成一块刺眼的亮白斑
    final scheme = Theme.of(context).colorScheme;

    if (error != null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          border: Border.all(color: scheme.error),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '解析失败',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.error,
              ),
            ),
            const SizedBox(height: 6),
            Text(error!, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }
    if (preview == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // 成功提示：用主色容器色，深浅模式下都是"低饱和的一块底"
        color: scheme.primaryContainer,
        border: Border.all(color: scheme.primary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '解析成功，预览前 ${preview!.length} 条：',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...preview!.map(
            (a) => ListTile(
              dense: true,
              leading: a.thumbUrl.isEmpty
                  ? const Icon(Icons.image, size: 32)
                  : null,
              title: Text(
                a.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                a.summary ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
