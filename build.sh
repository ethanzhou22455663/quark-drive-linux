#!/usr/bin/env bash
# build.sh — 从夸克网盘 Windows 版安装目录构建 Linux AppImage
#
# 用法:
#   ./build.sh <夸克Windows安装目录> [输出目录]
#   示例: ./build.sh ~/QuarkCloudDrive ./build-out
#
# <夸克Windows安装目录> 指官方 Windows 客户端的安装根目录，
# 其下应包含数字版本子目录（如 7.3.5.810/）。
#
# 依赖（构建机）:
#   curl, tar, imagemagick (ico->png), bash 4+
#   系统需已安装 Noto Sans CJK 字体（如 Arch: pacman -S noto-fonts-cjk）
#   appimagetool 若缺失会自动从 GitHub 下载
set -euo pipefail

QUARK_SRC="${1:?用法: ./build.sh <夸克Windows安装目录> [输出目录]}"
OUT_DIR="${2:-$(pwd)/build-out}"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

WINE_VER="11.18"
WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VER}/wine-${WINE_VER}-staging-amd64-wow64.tar.xz"
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/continuous/download/appimagetool-x86_64.AppImage"
APP_DIR_NAME="7.3.5.810"   # 会在步骤1中按实际版本号重写
DEFAULT_DPI=200            # 百分比，LogPixels = DPI*96/100

log() { printf '\e[1;32m==> %s\e[0m\n' "$*"; }
die() { printf '\e[1;31m错误: %s\e[0m\n' "$*" >&2; exit 1; }

fetch() { # fetch <url> <输出文件> [缓存标记]
    local url="$1" out="$2" tag="$WORK/.done_$(basename "$3" 2>/dev/null || echo "$2")"
    [ -f "$tag" ] && { log "跳过（已缓存）: $(basename "$out")"; return; }
    log "下载: $url"
    curl -sL --retry 5 --retry-delay 5 --retry-all-errors -o "$out" "$url" \
        || die "下载失败: $url"
    touch "$tag"
}

# ---------- 步骤 1: 定位并组装应用目录 ----------
log "步骤 1/6: 组装应用目录"
[ -d "$QUARK_SRC" ] || die "目录不存在: $QUARK_SRC"
VER_SUBDIR=$(find "$QUARK_SRC" -maxdepth 1 -type d -name '*.*.*.*' | head -1 || true)
if [ -n "${VER_SUBDIR:-}" ]; then
    APP_DIR_NAME=$(basename "$VER_SUBDIR")
    APP_SRC="$VER_SUBDIR"
else
    APP_SRC="$QUARK_SRC"   # 目录本身就是应用根（无版本子目录结构）
fi
log "应用版本目录: $APP_DIR_NAME"

APPDIR="$OUT_DIR/QuarkNetdisk.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/runtime"
cp -a "$APP_SRC" "$APPDIR/runtime/app"
rm -f "$APPDIR"/runtime/app/unins000.*   # Inno 卸载器，无用

# ---------- 步骤 2: 获取 Wine (Kron4ek wow64) ----------
log "步骤 2/6: 获取 Wine ${WINE_VER} (wow64)"
fetch "$WINE_URL" "$WORK/wine.tar.xz" wine
tar -xf "$WORK/wine.tar.xz" -C "$WORK"
mv "$WORK"/wine-*-staging-amd64-wow64 "$APPDIR/runtime/wine"
WINE="$APPDIR/runtime/wine/bin/wine"

# ---------- 步骤 3: 构建预配置 prefix 模板 ----------
log "步骤 3/6: 构建 Wine prefix 模板"
TPL="$APPDIR/runtime/prefix-template"
export WINEPREFIX="$TPL" WINEARCH="win64" WINEDEBUG="-all"
export WINEDLLOVERRIDES="mscoree,mshtml="   # 屏蔽 Wine Mono / Gecko 安装弹窗（Electron 用不到）
"$WINE" wineboot -i >/dev/null 2>&1 || true
"$APPDIR/runtime/wine/bin/wineserver" -w 2>/dev/null || true
unset WINEDLLOVERRIDES

# 中文字体
FONT_DIR="$TPL/drive_c/windows/Fonts"; mkdir -p "$FONT_DIR"
FONT_SRC=$(find /usr/share/fonts -name "NotoSansCJK-Regular.ttc" 2>/dev/null | head -1 || true)
[ -n "$FONT_SRC" ] || die "未找到 Noto Sans CJK 字体，请先安装（如: pacman -S noto-fonts-cjk）"
cp "$FONT_SRC" "$FONT_DIR/"
FONT_BOLD=$(find /usr/share/fonts -name "NotoSansCJK-Bold.ttc" 2>/dev/null | head -1)
[ -n "$FONT_BOLD" ] && cp "$FONT_BOLD" "$FONT_DIR/"

FS="HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontSubstitutes"
FL="HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\FontLink\\SystemLink"
# DPI（默认 200%）
"$WINE" reg add "HKCU\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d $((DEFAULT_DPI * 96 / 100)) /f >/dev/null
# 系统对话框中文字体替换（修复文件选择框豆腐块）
for v in "MS Shell Dlg" "MS Shell Dlg 2" "Tahoma"; do
    "$WINE" reg add "$FS" /v "$v" /t REG_SZ /d "Noto Sans CJK SC" /f >/dev/null
done
for v in "Tahoma" "MS Shell Dlg" "Segoe UI"; do
    "$WINE" reg add "$FL" /v "$v" /t REG_MULTI_SZ /d "Noto Sans CJK SC,NotoSansCJK-Regular.ttc" /f >/dev/null
done
"$APPDIR/runtime/wine/bin/wineserver" -k 2>/dev/null || true
sleep 2

# ---------- 步骤 4: 图标 ----------
log "步骤 4/6: 生成图标"
ICO=$(find "$APPDIR/runtime/app" -maxdepth 2 -name "quark_cloud_drive.ico" | head -1)
[ -n "$ICO" ] || die "未找到 quark_cloud_drive.ico"
( cd "$WORK" && magick "$ICO" -background none icon.png 2>/dev/null || convert "$ICO" -background none icon.png )
BIGGEST=$(ls -S "$WORK"/icon-*.png "$WORK"/icon.png 2>/dev/null | head -1)
cp "$BIGGEST" "$APPDIR/icon.png"
cp "$APPDIR/icon.png" "$APPDIR/.DirIcon"

# ---------- 步骤 5: AppRun / desktop ----------
log "步骤 5/6: 写入 AppRun 与 desktop"
sed "s/7\.3\.5\.810/$APP_DIR_NAME/g" "$REPO_DIR/AppRun" > "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"
cp "$REPO_DIR/quark.desktop" "$APPDIR/quark.desktop"

# ---------- 步骤 6: 打包 ----------
log "步骤 6/6: 打包 AppImage"
mkdir -p "$OUT_DIR"
AIT="$OUT_DIR/.appimagetool.AppImage"
fetch "$APPIMAGETOOL_URL" "$AIT" appimagetool
chmod +x "$AIT"
"$AIT" --appimage-extract-and-run "$APPDIR" "$OUT_DIR/QuarkNetdisk-x86_64.AppImage" > /dev/null
rm -f "$AIT"

log "完成: $OUT_DIR/QuarkNetdisk-x86_64.AppImage"
( cd "$OUT_DIR" && sha256sum QuarkNetdisk-x86_64.AppImage | tee QuarkNetdisk-x86_64.AppImage.sha256 )
