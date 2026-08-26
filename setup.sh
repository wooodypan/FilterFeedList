#!/usr/bin/env bash
# 项目初始化一键脚本（macOS / Linux，Windows 请用 Git Bash 执行）：
#   1) 拉取依赖（生成 .dart_tool/package_config.json）
#   2) 把 dart_jieba 自带的词典复制到 assets/dict.dgz
#
# 克隆仓库后执行一次即可：
#   ./setup.sh

set -e

# 切到脚本所在目录（项目根目录），无论从哪里调用都能正确定位
cd "$(dirname "$0")"

echo "==> flutter pub get"
flutter pub get

echo "==> 复制分词词典（dart_jieba -> assets/dict.dgz）"
dart run tools/fetch_dict.dart
