#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local PKG_LIST=("$PKG_NAME" $5)
    local REPO_NAME=${PKG_REPO#*/}

    echo " "

    # 删除本地可能存在的不同名称的软件包
    for NAME in "${PKG_LIST[@]}"; do
        echo "Search directory: $NAME"
        local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

        if [ -n "$FOUND_DIRS" ]; then
            while read -r DIR; do
                rm -rf "$DIR"
                echo "Delete directory: $DIR"
            done <<< "$FOUND_DIRS"
        else
            echo "Not found directory: $NAME"
        fi
    done

    # 克隆仓库 - 添加错误处理
    echo "Cloning $PKG_REPO with branch $PKG_BRANCH..."
    if git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git" 2>/dev/null; then
        echo "Successfully cloned $PKG_REPO"
    else
        echo "Warning: Failed to clone $PKG_REPO with branch $PKG_BRANCH, trying without branch specification..."
        git clone --depth=1 "https://github.com/$PKG_REPO.git"
    fi

    # 处理克隆的仓库
    if [[ "$PKG_SPECIAL" == "pkg" ]]; then
        find ./"$REPO_NAME"/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
        rm -rf ./"$REPO_NAME"/
    elif [[ "$PKG_SPECIAL" == "name" ]]; then
        mv -f "$REPO_NAME" "$PKG_NAME"
    fi
}

# ====================================================================
# 添加缺失的包 (注意：分支名已根据报错调整)
# ====================================================================

echo "开始添加缺失的包..."

# 1. WRTBwmon
echo "添加 wrtbwmon..."
UPDATE_PACKAGE "wrtbwmon" "brvphoenix/wrtbwmon" "master"
UPDATE_PACKAGE "luci-app-wrtbwmon" "brvphoenix/luci-app-wrtbwmon" "master"

# 2. Lucky - 修复分支问题
echo "添加 lucky..."
UPDATE_PACKAGE "lucky" "gdy666/lucky" "master"
# Lucky的luci应用可能使用main分支或没有指定分支
UPDATE_PACKAGE "luci-app-lucky" "gdy666/luci-app-lucky" "main"

# 3. rtp2httpd - 修复分支和仓库问题
echo "添加 rtp2httpd..."
UPDATE_PACKAGE "rtp2httpd" "stackia/rtp2httpd" "main"
# rtp2httpd的luci应用可能需要使用其他仓库或不同的协议
UPDATE_PACKAGE "luci-app-rtp2httpd" "zhangjianqing/luci-app-rtp2httpd" "master"

echo "缺失包添加完成！"

# ====================================================================
# 原有的其他包
# ====================================================================

echo "开始添加其他主题和插件..."
# (此处省略中间重复的主题插件代码以节省篇幅，保持原样即可)
# ... (保持原有代码不变) ...

# ====================================================================
# 修复核心报错点：UPDATE_VERSION 函数
# ====================================================================

UPDATE_VERSION() {
    local PKG_NAME=$1
    local PKG_MARK=${2:-false}
    local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

    if [ -z "$PKG_FILES" ]; then
        echo "$PKG_NAME not found!"
        return
    fi

    echo -e "\n$PKG_NAME version update has started!"

    for PKG_FILE in $PKG_FILES; do
        local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
        
        if [ -z "$PKG_REPO" ]; then
            echo "Cannot extract repo from $PKG_FILE"
            continue
        fi
        
        local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

        if [ -z "$PKG_TAG" ] || [ "$PKG_TAG" = "null" ]; then
            echo "Cannot get latest tag for $PKG_REPO"
            continue
        fi

        local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
        local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
        local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
        local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

        local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")
        local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
        local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
        local NEW_HASH=$(curl -sL "$NEW_URL" 2>/dev/null | sha256sum | cut -d ' ' -f 1)

        echo "old version: $OLD_VER $OLD_HASH"
        echo "new version: $NEW_VER $NEW_HASH"

        # 关键修复：使用正确的正则表达式运算符 =~（波浪线紧挨等号）
        if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "$PKG_FILE version has been updated!"
        else
            echo "$PKG_FILE version is already the latest!"
        fi
    done
}

# ====================================================================
# 执行更新
# ====================================================================

echo "开始更新软件包版本..."
UPDATE_VERSION "sing-box"
UPDATE_VERSION "lucky"
echo "版本更新完成！"
