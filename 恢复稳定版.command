#!/bin/sh
# Recover into a separate directory; never reset or overwrite the working game.
set -eu
TAG=v0.3.0
GAME_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PARENT_DIR=$(dirname -- "$GAME_DIR")
case "${1:-}" in
  ''|--no-open) ;;
  *) echo '用法：双击恢复稳定版.command，或添加 --no-open 仅恢复文件。' >&2; exit 2 ;;
esac
if git -C "$GAME_DIR" rev-parse --verify "refs/tags/$TAG^{commit}" >/dev/null 2>&1; then
  RESTORE_SOURCE=$GAME_DIR
elif [ -f "$PARENT_DIR/scrapbound-backups/$TAG/scrapbound-$TAG.git.bundle" ]; then
  RESTORE_SOURCE="$PARENT_DIR/scrapbound-backups/$TAG/scrapbound-$TAG.git.bundle"
elif [ -f "$PARENT_DIR/scrapbound-$TAG.git.bundle" ]; then
  RESTORE_SOURCE="$PARENT_DIR/scrapbound-$TAG.git.bundle"
else
  echo "未找到稳定版存档。请从 GitHub 的 $TAG 发布下载 Git bundle，放到游戏目录旁边再运行。" >&2
  echo '也可直接下载该发布的 project.zip，解压后启动。' >&2
  exit 1
fi
RESTORE_DIR=$(mktemp -d "$PARENT_DIR/scrapbound-$TAG-restored-XXXXXX")
echo "正在恢复 $TAG 到新目录，当前游戏文件会保留……"
git clone --quiet --no-hardlinks --no-checkout "$RESTORE_SOURCE" "$RESTORE_DIR"
git -C "$RESTORE_DIR" switch --quiet -c "restored-$TAG" "$TAG"
git -C "$RESTORE_DIR" remote set-url origin https://github.com/spoy-ai/scrapbound.git
printf '\n恢复完成：%s\n原目录保持不变。\n' "$RESTORE_DIR"
if [ "${1:-}" != '--no-open' ]; then
  /usr/bin/open "$RESTORE_DIR/缝隙求生.app"
fi
