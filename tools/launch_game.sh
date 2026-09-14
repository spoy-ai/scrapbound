#!/bin/sh
set -eu
GAME_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$GAME_DIR/captures"
if [ -n "${SCRAPBOUND_GODOT_BIN:-}" ]; then
  ENGINE=$SCRAPBOUND_GODOT_BIN
elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
  ENGINE=/Applications/Godot.app/Contents/MacOS/Godot
elif command -v godot >/dev/null 2>&1; then
  ENGINE=$(command -v godot)
elif command -v godot4 >/dev/null 2>&1; then
  ENGINE=$(command -v godot4)
else
  echo '请先安装 Godot 4 标准版，再启动游戏。此版本在 Godot 4.7.2 上验证。' >&2
  exit 1
fi
if [ ! -f "$GAME_DIR/.godot/scrapbound-imported" ]; then
  echo '首次启动正在准备游戏资源，请稍候……'
  "$ENGINE" --headless --path "$GAME_DIR" --editor --import --quit --log-file "$GAME_DIR/captures/first-launch-import.log"
  touch "$GAME_DIR/.godot/scrapbound-imported"
fi
exec "$ENGINE" --path "$GAME_DIR" --log-file "$GAME_DIR/captures/play.log" "$@"
