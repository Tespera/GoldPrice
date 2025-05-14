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

# 步骤6：复制Assets目录中的AppIcon.icns到Resources目录
echo -e "${BLUE}正在复制应用图标...${NC}"
if [ -f "Assets/AppIcon.icns" ]; then
    cp -f "Assets/AppIcon.icns" "${RESOURCES_DIR}/"
        # 更新Info.plist中的图标引用
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon.icns" "${CONTENTS_DIR}/Info.plist"
    echo -e "${GREEN}成功复制图标文件${NC}"
else
    echo -e "${RED}无法找到图标文件: Assets/AppIcon.icns${NC}"
    exit 1
fi

# 步骤7：创建PkgInfo文件
echo -e "${BLUE}正在创建PkgInfo文件...${NC}"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 步骤8：设置可执行权限
echo -e "${BLUE}正在设置可执行权限...${NC}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 步骤9：拷贝到应用程序目录（可选）
echo -e "${BLUE}是否要将应用拷贝到应用程序目录？(y/n)${NC}"
read -p "" COPY_TO_APPLICATIONS

if [[ "${COPY_TO_APPLICATIONS}" == "y" ]]; then
    echo -e "${BLUE}正在拷贝到应用程序目录...${NC}"
    cp -R "${APP_BUNDLE}" "/Applications/"
    echo -e "${GREEN}应用程序已安装到应用程序目录！${NC}"
fi

echo -e "${GREEN}===== ${APP_NAME} 应用构建完成 =====${NC}"
echo -e "${GREEN}应用程序包位置: $(pwd)/${APP_BUNDLE}${NC}" 