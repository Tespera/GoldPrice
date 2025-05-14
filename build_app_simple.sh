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

# 步骤6：生成图标并复制到Resources目录
echo -e "${BLUE}正在生成应用图标...${NC}"

# 检查是否已安装librsvg
if ! command -v rsvg-convert &> /dev/null; then
    echo -e "${RED}librsvg未安装，无法生成图标。请先安装：${NC}"
    echo -e "${BLUE}brew install librsvg${NC}"
    echo -e "${BLUE}跳过图标生成步骤...${NC}"
else
    # 创建iconset目录
    ICONSET_DIR="GoldPrice.iconset"
    mkdir -p "${ICONSET_DIR}"
    
    # 生成不同大小的PNG图像
    for SIZE in 16 32 128 256 512; do
        # 标准分辨率
        rsvg-convert -w ${SIZE} -h ${SIZE} GoldPriceIcon.svg > "${ICONSET_DIR}/icon_${SIZE}x${SIZE}.png"
        echo -e "✓ 已创建 ${SIZE}x${SIZE} 图标"
        
        # 高分辨率(@2x)
        DOUBLE=$((SIZE * 2))
        rsvg-convert -w ${DOUBLE} -h ${DOUBLE} GoldPriceIcon.svg > "${ICONSET_DIR}/icon_${SIZE}x${SIZE}@2x.png"
        echo -e "✓ 已创建 ${SIZE}x${SIZE}@2x 图标"
    done
    
    # 生成icns文件
    echo -e "${BLUE}正在生成icns图标文件...${NC}"
    iconutil -c icns "${ICONSET_DIR}" || {
        echo -e "${RED}图标生成失败！${NC}"
    }
    
    # 移动图标到Resources目录
    if [ -f "${APP_NAME}.icns" ]; then
        mv "${APP_NAME}.icns" "${RESOURCES_DIR}/"
        # 更新Info.plist中的图标引用
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile ${APP_NAME}.icns" "${CONTENTS_DIR}/Info.plist"
        echo -e "${GREEN}图标已添加到应用程序包${NC}"
    fi
    
    # 清理iconset目录
    rm -rf "${ICONSET_DIR}"
fi

# 步骤7：创建PkgInfo文件
echo -e "${BLUE}正在创建PkgInfo文件...${NC}"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 步骤8：设置可执行权限
echo -e "${BLUE}正在设置可执行权限...${NC}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo -e "${GREEN}===== ${APP_NAME} 应用构建完成 =====${NC}"
echo -e "${GREEN}应用程序包位置: $(pwd)/${APP_BUNDLE}${NC}"
echo -e "${BLUE}如需安装到应用程序目录，请手动执行: ${NC}"
echo -e "${BLUE}cp -R \"${APP_BUNDLE}\" \"/Applications/\"${NC}" 