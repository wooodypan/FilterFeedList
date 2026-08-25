/// 表单校验工具：集中放 URL / JSONPath 的合法性判断，方便配置页复用。
class Validators {
  /// 校验必填且是合法 URL。
  static String? requiredUrl(String? value) {
    if (value == null || value.trim().isEmpty) return '该项必填';
    final v = value.trim();
    // 允许带 {page}/{pageSize} 占位符，先替换掉再校验
    final cleaned = v
        .replaceAll('{page}', '1')
        .replaceAll('{pageSize}', '20');
    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasAbsolutePath && uri.scheme.isEmpty) {
      return '请输入合法的 URL（含 http/https）';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'URL 必须以 http/https 开头';
    }
    return null;
  }

  /// 校验必填文本
  static String? required(String? value, [String hint = '该项必填']) {
    if (value == null || value.trim().isEmpty) return hint;
    return null;
  }

  /// 校验 JSONPath 路径格式（简单版：只允许字母数字、点、下划线、方括号数字）。
  /// 不保证一定取得到值，只挡住明显写错的格式。
  static String? jsonPath(String? value, [String hint = '路径格式有误']) {
    if (value == null || value.trim().isEmpty) return hint;
    final v = value.trim();
    final ok = RegExp(r'^[A-Za-z0-9_\[\].]+$').hasMatch(v);
    if (!ok) return '仅允许字母数字、. 和 [下标]';
    return null;
  }
}
