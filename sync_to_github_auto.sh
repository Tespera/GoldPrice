#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置信息
GITHUB_USERNAME="Tespera"    # 在这里填入您的GitHub用户名
GITHUB_REPO="GoldPrice"      # 在这里填入您的仓库名称

echo -e "${BLUE}===== GitHub 代码同步工具 (自动分支检测) =====${NC}"

# 函数：检查配置
check_config() {
    if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITHUB_REPO" ]; then
        echo -e "${RED}错误: 请先配置GitHub用户名和仓库名称${NC}"
        echo -e "${YELLOW}请编辑脚本文件，在顶部设置以下变量:${NC}"
        echo -e "${BLUE}GITHUB_USERNAME=\"your_username\"${NC}"
        echo -e "${BLUE}GITHUB_REPO=\"your_repository\"${NC}"
        exit 1
    fi
}

# 函数：获取当前分支
get_current_branch() {
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    
    if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
        echo -e "${YELLOW}当前不在任何分支上，将使用 main 分支${NC}"
        CURRENT_BRANCH="main"
        git checkout -b main 2>/dev/null || git checkout main 2>/dev/null
    fi
    
    echo -e "${BLUE}当前分支: ${CURRENT_BRANCH}${NC}"
}

# 函数：检查Git仓库状态
check_git_repo() {
    if [ ! -d ".git" ]; then
        echo -e "${YELLOW}当前目录不是Git仓库，正在初始化...${NC}"
        git init
        git remote add origin "https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}.git"
        echo -e "${GREEN}✓ Git仓库初始化完成${NC}"
    else
        # 检查远程仓库配置
        REMOTE_URL=$(git remote get-url origin 2>/dev/null)
        EXPECTED_URL="https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}.git"
        
        if [ "$REMOTE_URL" != "$EXPECTED_URL" ]; then
            echo -e "${YELLOW}更新远程仓库地址...${NC}"
            git remote set-url origin "$EXPECTED_URL"
            echo -e "${GREEN}✓ 远程仓库地址已更新${NC}"
        fi
    fi
}

# 函数：检查工作区状态
check_working_directory() {
    if [ -z "$(git status --porcelain)" ]; then
        echo -e "${YELLOW}工作区没有变更，无需同步${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}检测到以下变更:${NC}"
    git status --short
    echo ""
}

# 函数：获取提交信息
get_commit_message() {
    echo -e "${BLUE}请输入提交信息 (直接回车使用默认信息):${NC}"
    read -p "提交信息: " COMMIT_MESSAGE
    
    if [ -z "$COMMIT_MESSAGE" ]; then
        COMMIT_MESSAGE="更新代码 - $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    echo -e "${GREEN}提交信息: ${COMMIT_MESSAGE}${NC}"
}

# 函数：执行Git操作
perform_git_operations() {
    echo -e "${BLUE}正在添加文件到暂存区...${NC}"
    git add .
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 添加文件失败${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ 文件已添加到暂存区${NC}"
    
    echo -e "${BLUE}正在提交变更...${NC}"
    git commit -m "$COMMIT_MESSAGE"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 提交失败${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ 变更已提交${NC}"
    
    echo -e "${BLUE}正在推送到GitHub (分支: ${CURRENT_BRANCH})...${NC}"
    git push origin "$CURRENT_BRANCH"
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}推送失败，尝试设置上游分支...${NC}"
        git push --set-upstream origin "$CURRENT_BRANCH"
        
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}设置上游分支失败，尝试强制推送...${NC}"
            echo -e "${RED}警告: 这将覆盖远程仓库的历史记录${NC}"
            read -p "是否继续强制推送? (y/N): " FORCE_PUSH
            
            case "$FORCE_PUSH" in
                [yY]|[yY][eE][sS])
                    git push --force origin "$CURRENT_BRANCH"
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✓ 强制推送成功${NC}"
                    else
                        echo -e "${RED}错误: 强制推送失败${NC}"
                        exit 1
                    fi
                    ;;
                *)
                    echo -e "${YELLOW}已取消推送${NC}"
                    exit 1
                    ;;
            esac
        else
            echo -e "${GREEN}✓ 推送成功${NC}"
        fi
    else
        echo -e "${GREEN}✓ 推送成功${NC}"
    fi
}

# 函数：显示仓库信息
show_repo_info() {
    echo -e "${GREEN}===== 同步完成 =====${NC}"
    echo -e "${BLUE}仓库地址: https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO}${NC}"
    echo -e "${BLUE}分支: ${CURRENT_BRANCH}${NC}"
    echo -e "${BLUE}最新提交: ${COMMIT_MESSAGE}${NC}"
    
    # 获取最新提交的哈希值
    LATEST_COMMIT=$(git rev-parse --short HEAD)
    echo -e "${BLUE}提交哈希: ${LATEST_COMMIT}${NC}"
}

# 主执行流程
main() {
    # 检查配置
    check_config
    
    # 检查Git仓库
    check_git_repo
    
    # 获取当前分支
    get_current_branch
    
    # 检查工作区状态
    check_working_directory
    
    # 获取提交信息
    get_commit_message
    
    # 确认操作
    echo -e "${YELLOW}即将同步到: https://github.com/${GITHUB_USERNAME}/${GITHUB_REPO} (分支: ${CURRENT_BRANCH})${NC}"
    read -p "确认继续? (Y/n): " CONFIRM
    
    case "$CONFIRM" in
        [nN]|[nN][oO])
            echo -e "${YELLOW}已取消同步${NC}"
            exit 0
            ;;
        *)
            # 执行Git操作
            perform_git_operations
            
            # 显示结果
            show_repo_info
            ;;
    esac
}

# 执行主函数
main 