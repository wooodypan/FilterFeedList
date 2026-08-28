import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/data_source_config.dart';
import '../../models/feed_article.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_source_provider.dart';
import '../../utils/validators.dart';

/// RSS 订阅源的示例地址（编辑页新增时预填，开箱即可测试）。
const String kExampleRssUrl = 'https://www.ruanyifeng.com/blog/atom.xml';

/// RSS/Atom 订阅源配置页。
///
/// 相比 JSONPath 配置页（[DataSourceEditPage]）非常精简：
/// 只需要"名称 + feed 地址"就能订阅，不用填任何字段映射——
/// 标题/链接/时间这些字段 RSS/Atom 协议本身已经约定好了。
class RssSourceEditPage extends ConsumerStatefulWidget {
  /// 编辑时传入已存在的配置；新增时为 null
  final DataSourceConfig? initial;

  /// 从「推荐订阅」页导入时，仅预填 feed 地址；名称留空，让用户自己填写
  final String? presetUrl;

  const RssSourceEditPage({super.key, this.initial, this.presetUrl});

  @override
  ConsumerState<RssSourceEditPage> createState() => _RssSourceEditPageState();
}

class _RssSourceEditPageState extends ConsumerState<RssSourceEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _urlC = TextEditingController();

  // 详情渲染方式（同 JSONPath 源：webview 开原文 / native 渲染全文 HTML）
  DetailRenderMode _detailMode = DetailRenderMode.webview;

  // 测试预览结果
  List<FeedArticle>? _preview;
  String? _previewError;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    if (c != null) {
      _nameC.text = c.name;
      _urlC.text = c.apiUrl;
      _detailMode = c.detailMode;
    } else if (widget.presetUrl != null) {
      // 从「推荐订阅」导入：预填地址，名称留空让用户编辑
      _urlC.text = widget.presetUrl!;
    } else {
      // 新增时预填示例源，降低上手成本
      _urlC.text = kExampleRssUrl;
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _urlC.dispose();
    super.dispose();
  }

  /// 把表单组装成一份 DataSourceConfig（测试 / 保存共用）。
  /// RSS 源没有字段映射，feed 地址直接复用 apiUrl 存。
  DataSourceConfig _buildConfig({required String id}) {
    return DataSourceConfig(
      id: id,
      name: _nameC.text.trim(),
      sourceType: DataSourceType.rss,
      apiUrl: _urlC.text.trim(),
      detailMode: _detailMode,
    );
  }

  /// 测试订阅：立即请求一次并解析，展示前 3 条预览
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
          .read(rssFeedRepositoryProvider)
          .fetchFeed(temp);
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
      context.pop();
    }
  }

  bool _validate() => _formKey.currentState?.validate() ?? false;

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? '订阅 RSS' : '编辑 RSS 订阅'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameC,
                decoration: const InputDecoration(
                  labelText: '订阅名称',
                  hintText: '如：阮一峰的网络日志',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? '该项必填' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlC,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'RSS / Atom 地址',
                  hintText: kExampleRssUrl,
                  border: OutlineInputBorder(),
                ),
                validator: Validators.requiredUrl,
              ),
              const SizedBox(height: 12),
              const Text(
                '详情页渲染方式',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              RadioGroup<DetailRenderMode>(
                groupValue: _detailMode,
                onChanged: (v) => setState(() => _detailMode = v!),
                child: const Column(
                  children: [
                    RadioListTile<DetailRenderMode>(
                      title: Text('WebView（加载原文链接）'),
                      value: DetailRenderMode.webview,
                    ),
                    RadioListTile<DetailRenderMode>(
                      title: Text('原生渲染（feed 提供全文时无广告更清爽）'),
                      value: DetailRenderMode.native,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                  label: Text(_testing ? '测试中…' : '测试订阅并预览'),
                ),
              ),
              _PreviewSection(preview: _preview, error: _previewError),
            ],
          ),
        ),
      ),
    );
  }
}

/// 测试预览区：成功显示前 3 条，失败显示具体错误。
/// （交互与 JSONPath 配置页的预览区保持一致）
class _PreviewSection extends StatelessWidget {
  final List<FeedArticle>? preview;
  final String? error;

  const _PreviewSection({this.preview, this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '解析失败',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
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
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '订阅成功，预览前 ${preview!.length} 条：',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...preview!.map(
            (a) => ListTile(
              dense: true,
              leading: a.thumbUrl.isEmpty
                  ? const Icon(Icons.article, size: 32)
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
