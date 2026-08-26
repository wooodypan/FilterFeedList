// tools/fetch_dict.dart
//
// 项目初始化时执行一次：把 dart_jieba 依赖包自带的词典
// （assets/dict.dgz）复制到本项目的 assets/ 目录下。
//
// 为什么这么做？
// - 我们不想把 1.9MB 的二进制词典提交到 git 仓库；
// - dart_jieba 这个包本身已经带着 dict.dgz（pub 缓存里就有）；
// - 直接从「已安装」的包里复制，版本与 pubspec.lock 锁定的完全一致，
//   且不需要联网下载。
//
// 用法（在项目根目录执行）：
//   dart run tools/fetch_dict.dart
//
// 幂等性：如果目标文件已存在且大小一致，会直接跳过，不会重复复制。

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  // 项目根目录 = 本脚本所在目录(tools/)的上一级
  final projectRoot = File.fromUri(Platform.script).parent.parent;
  final packageConfigFile =
      File('${projectRoot.path}/.dart_tool/package_config.json');

  // 1) 确认依赖已经解析过（也就是运行过 flutter pub get）
  if (!await packageConfigFile.exists()) {
    stderr.writeln('找不到 .dart_tool/package_config.json，请先运行：flutter pub get');
    exit(1);
  }

  // 2) 从 package_config.json 里找到 dart_jieba 包的真实安装路径
  final config =
      jsonDecode(await packageConfigFile.readAsString()) as Map<String, dynamic>;
  final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
  final matches = packages.where((p) => p['name'] == 'dart_jieba');
  if (matches.isEmpty) {
    stderr.writeln('在依赖里没找到 dart_jieba，请确认 pubspec.yaml 已添加该依赖。');
    exit(1);
  }
  final dartJieba = matches.first;

  // rootUri 是 file:// 形式的 URI，用 Uri 解析成跨平台文件路径
  final rootUri = Uri.parse(dartJieba['rootUri'] as String);
  final packageDir = Directory(rootUri.toFilePath());
  final srcFile = File('${packageDir.path}/assets/dict.dgz');

  if (!await srcFile.exists()) {
    stderr.writeln(
      '在 dart_jieba 包里没找到 assets/dict.dgz（路径：${srcFile.path}）。\n'
      '可能是 dart_jieba 版本变化，请检查 pubspec.lock。',
    );
    exit(1);
  }

  // 3) 复制到本项目的 assets/dict.dgz
  final destDir = Directory('${projectRoot.path}/assets');
  if (!await destDir.exists()) {
    await destDir.create(recursive: true);
  }
  final destFile = File('${destDir.path}/dict.dgz');

  // 幂等：已存在且大小一致就跳过，不重复复制
  if (await destFile.exists()) {
    final srcSize = await srcFile.length();
    final dstSize = await destFile.length();
    if (dstSize == srcSize) {
      print('assets/dict.dgz 已存在且一致，跳过复制。');
      return;
    }
  }

  await srcFile.copy(destFile.path);
  print('已复制分词词典：');
  print('  来源：${srcFile.path}');
  print('  目标：${destFile.path}');
  print('词典就绪，可以运行 flutter run 了。');
}
