#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 定义应用名称和路径
APP_NAME="GoldPrice"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICON_SOURCE="Assets/AppIcon.icns"

echo -e "${BLUE}===== 开始构建 ${APP_NAME} 应用 =====${NC}"

# 步骤1：清理旧的构建文件
echo -e "${BLUE}正在清理旧的构建文件...${NC}"
rm -rf "${APP_BUNDLE}" .build
swift package clean

# 步骤2：编译项目
echo -e "${BLUE}正在编译项目...${NC}"
swift build -c release || {
    echo -e "${RED}编译失败！${NC}"
    exit 1
}

# 步骤3：创建应用程序目录结构
echo -e "${BLUE}正在创建应用程序目录结构...${NC}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# 步骤4：复制可执行文件
echo -e "${BLUE}正在复制可执行文件...${NC}"
cp -f ".build/release/${APP_NAME}" "${MACOS_DIR}/"

# 步骤5：复制Info.plist
echo -e "${BLUE}正在复制Info.plist...${NC}"
cp -f "Info.plist" "${CONTENTS_DIR}/"

# 步骤6：复制应用程序图标
echo -e "${BLUE}正在复制应用程序图标...${NC}"
if [ -f "${ICON_SOURCE}" ]; then
    cp -f "${ICON_SOURCE}" "${RESOURCES_DIR}/AppIcon.icns"
    # 确保Info.plist中的图标引用正确
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon.icns" "${CONTENTS_DIR}/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon.icns" "${CONTENTS_DIR}/Info.plist"
    echo -e "${GREEN}图标已添加到应用程序包${NC}"
else
    echo -e "${RED}警告：找不到图标文件 ${ICON_SOURCE}${NC}"
fi

# 步骤7：创建PkgInfo文件
echo -e "${BLUE}正在创建PkgInfo文件...${NC}"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 步骤8：设置可执行权限
echo -e "${BLUE}正在设置可执行权限...${NC}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 步骤9：验证应用程序包结构
echo -e "${BLUE}正在验证应用程序包结构...${NC}"
if [ -f "${MACOS_DIR}/${APP_NAME}" ] && [ -f "${CONTENTS_DIR}/Info.plist" ] && [ -f "${RESOURCES_DIR}/AppIcon.icns" ]; then
    echo -e "${GREEN}应用程序包结构验证成功${NC}"
else
    echo -e "${RED}应用程序包结构验证失败${NC}"
    exit 1
fi

echo -e "${GREEN}===== ${APP_NAME} 应用构建完成 =====${NC}"
echo -e "${GREEN}应用程序包位置: $(pwd)/${APP_BUNDLE}${NC}"
echo -e "${BLUE}如需安装到应用程序目录，请手动执行: ${NC}"
echo -e "${BLUE}cp -R \"${APP_BUNDLE}\" \"/Applications/\"${NC}"

# 显示应用程序包信息
echo -e "${BLUE}应用程序包内容:${NC}"
echo -e "${GREEN}可执行文件: ${MACOS_DIR}/${APP_NAME}${NC}"
echo -e "${GREEN}配置文件: ${CONTENTS_DIR}/Info.plist${NC}"
echo -e "${GREEN}图标文件: ${RESOURCES_DIR}/AppIcon.icns${NC}"

# 可选：自动打开Finder显示应用程序包
read -p "是否要在Finder中显示应用程序包？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open -R "${APP_BUNDLE}"
fi