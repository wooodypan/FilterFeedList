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

# 准备 .env.production：如果不存在，就从模板复制一份（里面是占位 key，可后补真实值）。
# 真实密钥文件已被 .gitignore 排除，不会误提交。
if [ ! -f .env.production ]; then
  cp .env.production.example .env.production
  echo "已生成 .env.production（如需自定义密钥，请编辑该文件）"
fi
