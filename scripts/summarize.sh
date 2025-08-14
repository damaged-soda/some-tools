#!/usr/bin/env bash
# 用法：
#   summarize.sh                             # 只打印目录树
#   summarize.sh . src pkg/utils             # 打印目录树 + 指定目录下代码
#   summarize.sh --no-test . pkg             # 排除 _test.go 文件
#   summarize.sh -v vendor . src             # 排除路径中包含 vendor 的文件
#   summarize.sh -v vendor -v mocks src pkg  # 同时排除多个关键词

set -euo pipefail

# 项目根目录 = 当前工作目录
ROOT_DIR="$(pwd)"

# 处理参数
NO_TEST=false
EXCLUDE_KEYWORDS=()
DIRS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-test)
      NO_TEST=true
      shift
      ;;
    -v)
      if [[ $# -lt 2 ]]; then
        echo "错误: -v 需要一个关键词" >&2
        exit 2
      fi
      EXCLUDE_KEYWORDS+=("$2")
      shift 2
      ;;
    --) # 显式结束参数
      shift
      while [[ $# -gt 0 ]]; do DIRS+=("$1"); shift; done
      ;;
    -*)
      echo "未知参数: $1" >&2
      exit 2
      ;;
    *)
      DIRS+=("$1")
      shift
      ;;
  esac
done

# 组装供 tree 使用的忽略模式
TREE_IGNORE='.git|node_modules|vendor'
if [[ ${#EXCLUDE_KEYWORDS[@]} -gt 0 ]]; then
  for kw in "${EXCLUDE_KEYWORDS[@]}"; do
    # tree 的 -I 支持 | 分隔的通配符列表
    TREE_IGNORE+="|*${kw}*"
  done
fi

# 打印目录树（同样应用排除）
echo "<<目录树>>"
if command -v tree >/dev/null 2>&1; then
  tree -I "$TREE_IGNORE"
else
  # 无 tree 时用 find+sed 生成简易目录树，并在目录层面做 prune
  PRUNE_ARGS=( -name '.git' -o -name 'node_modules' -o -name 'vendor' )
  if [[ ${#EXCLUDE_KEYWORDS[@]} -gt 0 ]]; then
    for kw in "${EXCLUDE_KEYWORDS[@]}"; do
      PRUNE_ARGS+=( -o -path "*${kw}*" )
    done
  fi
  # shellcheck disable=SC2016
  find . -type d \( "${PRUNE_ARGS[@]}" \) -prune -o -print |
    sed -e 's/[^-][^\/]*\//   |/g' -e 's/|\([^ ]\)/|-- \1/'
fi

# 如果没有指定目录，就退出
if [[ ${#DIRS[@]} -eq 0 ]]; then
  exit 0
fi

echo

# 遍历用户指定的目录
for dir in "${DIRS[@]}"; do
  TARGET_DIR="$ROOT_DIR/$dir"
  if [[ ! -d "$TARGET_DIR" ]]; then
    echo "警告: 目录 $dir 不存在，跳过。" >&2
    continue
  fi

  # 组装 find 命令
  find_cmd=(find "$TARGET_DIR" -type f \( -name "*.go" -o -name "*.proto" -o -name "*.py" \) ! -name "*.pb.go")
  if [[ "$NO_TEST" == true ]]; then
    find_cmd+=( ! -name "*_test.go" )
  fi
  if [[ ${#EXCLUDE_KEYWORDS[@]} -gt 0 ]]; then
    for kw in "${EXCLUDE_KEYWORDS[@]}"; do
      find_cmd+=( ! -path "*${kw}*" )
    done
  fi

  "${find_cmd[@]}" | sort | while read -r file; do
    rel_path="${file#$ROOT_DIR/}"
    echo
    echo "<<$rel_path>>"
    cat "$file"
    echo
  done
done
