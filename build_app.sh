#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 定义应用名称和路径
APP_NAME="GoldPrice"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ARCHIVES_DIR="Archives"

echo -e "${BLUE}===== 开始构建 ${APP_NAME} 应用 =====${NC}"

# 函数：从Info.plist获取版本号
get_version() {
    if [ -f "Info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.0.0"
    else
        echo "1.0.0"
    fi
}

# 函数：更新版本号
update_version() {
    local current_version="$1"
    # 解析版本号（假设格式为 x.y.z）
    local major=$(echo "$current_version" | cut -d. -f1)
    local minor=$(echo "$current_version" | cut -d. -f2)
    local patch=$(echo "$current_version" | cut -d. -f3)
    
    # 将patch版本号增加1
    patch=$((patch + 1))
    
    local new_version="${major}.${minor}.${patch}"
    
    # 更新Info.plist中的版本号
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${new_version}" Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${new_version}" Info.plist
    
    echo "$new_version"
}

# 函数：询问是否更新版本号
ask_version_update() {
    local current_version=$(get_version)
    echo -e "${YELLOW}当前版本号: V${current_version}${NC}" >&2
    echo -e "${BLUE}是否要更新版本号？(Y/N): ${NC}\c" >&2
    read -r response
    
    case "$response" in
        [yY]|[yY][eE][sS])
            local new_version=$(update_version "$current_version")
            echo -e "${GREEN}✓ 版本号已更新: V${current_version} → V${new_version}${NC}" >&2
            echo "$new_version"
            ;;
        *)
            echo -e "${YELLOW}保持当前版本号: V${current_version}${NC}" >&2
            echo "$current_version"
            ;;
    esac
}

# 函数：归档现有版本
archive_existing_version() {
    local current_version="$1"
    
    if [ -d "${APP_BUNDLE}" ]; then
        echo -e "${YELLOW}正在归档当前版本...${NC}"
        
        # 获取现有版本号
        if [ -f "${APP_BUNDLE}/Contents/Info.plist" ]; then
            EXISTING_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist" 2>/dev/null || echo "unknown")
        else
            EXISTING_VERSION="unknown"
        fi
        
        # 创建归档目录（使用当前版本号）
        ARCHIVE_VERSION_DIR="${ARCHIVES_DIR}/V${current_version}"
        mkdir -p "${ARCHIVE_VERSION_DIR}"
        
        # 获取当前时间戳
        TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
        ARCHIVE_ZIP="${ARCHIVE_VERSION_DIR}/${APP_NAME}_V${EXISTING_VERSION}_${TIMESTAMP}.zip"
        
        # 压缩现有版本
        echo -e "${BLUE}正在压缩版本 V${EXISTING_VERSION} 到 ${ARCHIVE_ZIP}${NC}"
        if zip -rq "${ARCHIVE_ZIP}" "${APP_BUNDLE}"; then
            echo -e "${GREEN}✓ 版本 V${EXISTING_VERSION} 已归档到: ${ARCHIVE_ZIP}${NC}"
            
            # 删除现有版本
            rm -rf "${APP_BUNDLE}"
        else
            echo -e "${RED}✗ 归档失败${NC}"
            exit 1
        fi
    else
        echo -e "${BLUE}未发现版本更新，跳过归档步骤${NC}"
    fi
}


# 构建开始：
# 步骤1：询问是否更新版本号
CURRENT_VERSION=$(ask_version_update)

# 步骤2：归档现有版本（使用当前版本号归档）
archive_existing_version "$CURRENT_VERSION"

# 显示归档信息
if [ -d "${ARCHIVES_DIR}" ]; then
    ARCHIVE_COUNT=$(find "${ARCHIVES_DIR}" -name "*.zip" | wc -l | tr -d ' ')
    echo -e "${GREEN}历史版本归档统计: ${ARCHIVE_COUNT} 个版本已归档到 ${ARCHIVES_DIR} 目录${NC}"
fi

# 步骤3：清理构建文件和临时目录
echo -e "${BLUE}正在清理构建文件...${NC}"
rm -rf .build
swift package clean

# 步骤4：编译项目
echo -e "${BLUE}正在编译项目...${NC}"
swift build -c release || {
    echo -e "${RED}编译失败！${NC}"
    exit 1
}

# 步骤5：创建应用程序目录结构
echo -e "${BLUE}正在创建应用程序目录结构...${NC}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# 步骤6：复制可执行文件
echo -e "${BLUE}正在复制可执行文件...${NC}"
cp -f ".build/release/${APP_NAME}" "${MACOS_DIR}/"

# 步骤7：复制Info.plist
echo -e "${BLUE}正在复制Info.plist...${NC}"
cp -f "Info.plist" "${CONTENTS_DIR}/"

# 步骤8：复制应用图标
echo -e "${BLUE}正在复制应用图标...${NC}"
if [ -f "Assets/AppIcon.icns" ]; then
    cp -f "Assets/AppIcon.icns" "${RESOURCES_DIR}/"
    # 更新Info.plist中的图标引用
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon.icns" "${CONTENTS_DIR}/Info.plist" 2>/dev/null || {
        echo -e "${YELLOW}警告: 无法更新Info.plist中的图标引用${NC}"
    }
else
    echo -e "${RED}警告: 未找到Assets/AppIcon.icns文件${NC}"
fi

# 步骤9：创建PkgInfo文件
echo -e "${BLUE}正在创建PkgInfo文件...${NC}"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# 步骤10：设置可执行权限
echo -e "${BLUE}正在设置可执行权限...${NC}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

echo -e "${GREEN}===== ${APP_NAME} V${CURRENT_VERSION} 构建完成 =====${NC}"
echo -e "${GREEN}应用程序包: $(pwd)/${APP_BUNDLE}${NC}"
echo -e "${BLUE}如需安装到应用程序目录，请执行: ${NC}"
echo -e "${GREEN}sudo cp -R \"${APP_BUNDLE}\" \"/Applications/\"${NC}"

# 询问是否创建DMG安装包
echo -e "${BLUE}是否创建DMG安装包？(Y/N): ${NC}\c" >&2
read -r dmg_response

case "$dmg_response" in
    [yY]|[yY][eE][sS])
        if [ -f "create_dmg.sh" ]; then
            rm -f *.dmg temp_*.dmg
            echo -e "${BLUE}正在创建DMG安装包...${NC}"
            ./create_dmg.sh
        else
            echo -e "${RED}错误: 未找到DMG创建脚本 create_dmg.sh${NC}"
        fi
        ;;
    *)
        echo -e "${BLUE}已跳过DMG创建${NC}"
        ;;
esac

echo -e "${GREEN}===== 脚本执行完毕 =====${NC}"