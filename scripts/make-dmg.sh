#!/bin/zsh
# TaskBoard.app を Release でビルドし、/Applications へドラッグできる dmg を作る。
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_NAME="TaskBoard"
VERSION="$(awk '/MARKETING_VERSION/{print $2}' project.yml | tr -d '"')"
: "${VERSION:=0.0.0}"
BUILD_DIR="$ROOT/.build"
DIST="$ROOT/dist"
STAGE="$(mktemp -d)/$APP_NAME"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

trap 'rm -rf "$(dirname "$STAGE")"' EXIT

echo "==> プロジェクトを生成"
command -v xcodegen >/dev/null || { echo "xcodegen がありません: brew install xcodegen"; exit 1; }
xcodegen generate >/dev/null

echo "==> Release ビルド"
xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" \
           -configuration Release -derivedDataPath "$BUILD_DIR" build >/dev/null

APP="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "ビルド結果が見つかりません: $APP"; exit 1; }

echo "==> アドホック署名を付け直す"
# 署名が欠けていると Gatekeeper に「壊れている」と言われるため、毎回付け直す
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP" && echo "    署名OK"

echo "==> dmg の中身を組み立て"
mkdir -p "$STAGE" "$DIST"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> dmg を作成"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" \
               -ov -format UDZO "$DMG" >/dev/null

SIZE="$(du -h "$DMG" | cut -f1)"
echo ""
echo "完成: $DMG ($SIZE)"
echo "開いて $APP_NAME.app を Applications フォルダへドラッグしてください。"
