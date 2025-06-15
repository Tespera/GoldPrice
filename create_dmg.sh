#!/bin/bash

# DMG创建脚本

set -e

# 设置颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

APP_NAME="GoldPrice"
APP_BUNDLE="${APP_NAME}.app"

# 获取版本号
get_version() {
    if [ -f "Info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.0.0"
    else
        echo "1.0.0"
    fi
}

VERSION=$(get_version)
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BACKGROUND_FILE="Assets/dmg_bg.svg"

echo -e "${BLUE}===== 创建DMG安装包 =====${NC}"
echo -e "${YELLOW}应用程序: ${APP_BUNDLE}${NC}"
echo -e "${YELLOW}版本号: V${VERSION}${NC}"
echo -e "${YELLOW}DMG文件: ${DMG_NAME}${NC}"

# 检查应用程序是否存在
if [ ! -d "${APP_BUNDLE}" ]; then
    echo -e "${RED}错误: 未找到应用程序 ${APP_BUNDLE}${NC}"
    echo -e "${RED}请先运行构建脚本创建应用程序${NC}"
    exit 1
fi

# 清理旧的DMG文件
echo -e "${BLUE}正在清理旧的DMG文件...${NC}"
rm -f "${DMG_NAME}"

# 创建DMG安装包
echo -e "${BLUE}正在创建DMG安装包...${NC}"

TMP_DMG="tmp-${DMG_NAME}"
VOL_NAME="${APP_NAME}"
MOUNT_DIR="/Volumes/${VOL_NAME}"

# 强制卸载可能存在的挂载点
hdiutil detach "${MOUNT_DIR}" -force 2>/dev/null || true
killall hdiutil 2>/dev/null || true

# 删除临时文件
rm -f "${TMP_DMG}"

echo -e "${BLUE}正在从 ${APP_BUNDLE} 创建DMG...${NC}"

# 创建临时DMG
hdiutil create -volname "${VOL_NAME}" -srcfolder "${APP_BUNDLE}" -ov -format UDRW "${TMP_DMG}"

# 挂载DMG进行自定义
echo -e "${BLUE}正在挂载DMG进行自定义...${NC}"
hdiutil attach "${TMP_DMG}" -readwrite -noverify -noautoopen

# 等待挂载完成
sleep 2

if [ -d "${MOUNT_DIR}" ]; then
    echo -e "${BLUE}正在设置DMG布局...${NC}"
    
    # 创建Applications链接
    ln -s /Applications "${MOUNT_DIR}/Applications"
    
    # 创建背景目录并复制背景文件
    mkdir -p "${MOUNT_DIR}/.background"
    if [ -f "${BACKGROUND_FILE}" ]; then
        cp -f "${BACKGROUND_FILE}" "${MOUNT_DIR}/.background/"
    else
        echo -e "${YELLOW}警告: 未找到背景文件 ${BACKGROUND_FILE}${NC}"
    fi
    
    # 使用AppleScript设置DMG外观
    echo -e "${BLUE}正在设置DMG外观...${NC}"
    osascript -e "tell application \"Finder\"" \
        -e "tell disk \"${VOL_NAME}\"" \
        -e "open" \
        -e "set current view of container window to icon view" \
        -e "set toolbar visible of container window to false" \
        -e "set statusbar visible of container window to false" \
        -e "set the bounds of container window to {360, 100, 1080, 620}" \
        -e "set theViewOptions to the icon view options of container window" \
        -e "set arrangement of theViewOptions to not arranged" \
        -e "set icon size of theViewOptions to 80" \
        -e "set background picture of theViewOptions to file \".background:dmg_bg.svg\"" \
        -e "set position of item \"${APP_NAME}.app\" of container window to {220, 240}" \
        -e "set position of item \"Applications\" of container window to {520, 240}" \
        -e "update without registering applications" \
        -e "delay 5" \
        -e "close" \
        -e "end tell" \
        -e "end tell"
    
    # 等待设置完成
    sleep 5
    
    # 卸载DMG
    echo -e "${BLUE}正在卸载DMG...${NC}"
    hdiutil detach "${MOUNT_DIR}" -force
    
    # 转换为最终的压缩DMG
    echo -e "${BLUE}正在压缩DMG...${NC}"
    hdiutil convert "${TMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"
    
    # 清理临时文件
    rm -f "${TMP_DMG}"
    
    echo -e "${GREEN}✓ DMG安装包创建完成: ${DMG_NAME}${NC}"
    
    # 显示文件大小
    if [ -f "${DMG_NAME}" ]; then
        DMG_SIZE=$(du -h "${DMG_NAME}" | cut -f1)
        echo -e "${GREEN}DMG文件大小: ${DMG_SIZE}${NC}"
    fi
    
else
    echo -e "${RED}错误: 无法挂载DMG卷${NC}"
    rm -f "${TMP_DMG}"
    exit 1
fi

echo -e "${GREEN}===== DMG创建完成 =====${NC}" 