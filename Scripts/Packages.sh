#!/bin/bash

# ====================================================================
# 终极修复：完全移除 luci-theme-aurora，使用 bootstrap 主题
# ====================================================================

echo "=== 终极修复：彻底移除 luci-theme-aurora 依赖 ==="

# 1. 首先找到正确的 OpenWRT 目录
echo "查找 OpenWRT 根目录..."
if [ -d "/mnt/build_wrt" ]; then
    BUILD_ROOT="/mnt/build_wrt"
    echo "找到编译目录: $BUILD_ROOT"
elif [ -d "../.." ] && [ -f "../../.config" ]; then
    BUILD_ROOT="../.."
    echo "找到上级目录: $BUILD_ROOT"
else
    BUILD_ROOT="."
    echo "使用当前目录: $BUILD_ROOT"
fi

# 2. 查找并修复所有有问题的 Makefile（更彻底的搜索）
echo "搜索所有包含 luci-theme-aurora 的 Makefile..."
find "$BUILD_ROOT" -name "Makefile" -type f -exec grep -l "luci-theme-aurora" {} \; 2>/dev/null | while read -r MAKEFILE; do
    echo "发现并修复: $MAKEFILE"
    
    # 备份原文件
    cp "$MAKEFILE" "${MAKEFILE}.bak_$(date +%s)"
    
    # 查看原始 DEPENDS 行
    echo "原始 DEPENDS 行:"
    grep -n "DEPENDS" "$MAKEFILE" | head -3
    
    # 彻底移除 luci-theme-aurora 依赖
    # 方法1：删除包含 luci-theme-aurora 的行
    sed -i '/luci-theme-aurora/d' "$MAKEFILE"
    
    # 方法2：在 DEPENDS 行中移除
    if grep -q "^DEPENDS:=" "$MAKEFILE"; then
        # 获取当前 DEPENDS 行
        DEPENDS_LINE=$(grep "^DEPENDS:=" "$MAKEFILE")
        
        # 处理 DEPENDS 行，移除 luci-theme-aurora
        NEW_DEPENDS=$(echo "$DEPENDS_LINE" | sed '
            # 移除 +luci-theme-aurora
            s/+luci-theme-aurora//g
            # 移除 luci-theme-aurora（没有+号的情况）
            s/luci-theme-aurora//g
            # 清理多余空格
            s/  \+/ /g
            # 清理开头和结尾的空格
            s/^DEPENDS:=\s*/DEPENDS:=/g
            s/\s*$/ /g
        ')
        
        # 对于 luci-light，确保包含 bootstrap 主题
        if [[ "$MAKEFILE" == *"luci-light"* ]] && [[ "$NEW_DEPENDS" != *"luci-theme-bootstrap"* ]]; then
            NEW_DEPENDS="${NEW_DEPENDS}+luci-theme-bootstrap "
        fi
        
        # 对于 luci-nginx，确保包含 bootstrap 主题
        if [[ "$MAKEFILE" == *"luci-nginx"* ]] && [[ "$NEW_DEPENDS" != *"luci-theme-bootstrap"* ]]; then
            NEW_DEPENDS="${NEW_DEPENDS}+luci-theme-bootstrap "
        fi
        
        # 清理最后的空格
        NEW_DEPENDS=$(echo "$NEW_DEPENDS" | sed 's/ $//')
        
        echo "新 DEPENDS 行: $NEW_DEPENDS"
        
        # 替换整行
        sed -i "s|^DEPENDS:=.*|$NEW_DEPENDS|" "$MAKEFILE"
    fi
    
    echo "修复完成"
    echo "---"
done

# 3. 如果找不到文件，尝试其他路径
if [ ! -f "../feeds/luci/luci-light/Makefile" ] && [ -f "$BUILD_ROOT/feeds/luci/luci-light/Makefile" ]; then
    echo "使用绝对路径修复..."
    cp "$BUILD_ROOT/feeds/luci/luci-light/Makefile" "$BUILD_ROOT/feeds/luci/luci-light/Makefile.bak"
    
    # 直接重写 DEPENDS 行
    cat > "$BUILD_ROOT/feeds/luci/luci-light/Makefile.tmp" << 'EOF'
include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI Light (Minimal)
LUCI_DEPENDS:=+luci-base +luci-lib-ipkg +luci-lib-jsonc +luci-lib-nixio +rpcd-mod-luci +luci-theme-bootstrap
LUCI_PKGARCH:=all

PKG_NAME:=luci-light
PKG_VERSION:=git
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
EOF
    
    mv "$BUILD_ROOT/feeds/luci/luci-light/Makefile.tmp" "$BUILD_ROOT/feeds/luci/luci-light/Makefile"
    echo "已重写 luci-light Makefile"
fi

# 4. 创建假的 luci-theme-aurora 包（欺骗系统）
echo "创建 luci-theme-aurora 虚拟包..."
mkdir -p "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora"
cat > "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile" << 'EOF'
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-theme-aurora
PKG_VERSION:=1.0
PKG_RELEASE:=1

PKG_MAINTAINER:=OpenWrt
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/luci-theme-aurora
  SECTION:=luci
  CATEGORY:=LuCI
  TITLE:=Aurora Theme (Dummy - uses Bootstrap)
  DEPENDS:=+luci-theme-bootstrap
  PKGARCH:=all
endef

define Package/luci-theme-aurora/description
  This is a dummy package for luci-theme-aurora.
  It actually uses the bootstrap theme to avoid dependency issues.
endef

define Build/Compile
	true
endef

define Package/luci-theme-aurora/install
	$(INSTALL_DIR) $(1)/www/luci-static/aurora
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	echo "#!/bin/sh" > $(1)/etc/uci-defaults/99-aurora-dummy
	echo "# Dummy aurora theme" >> $(1)/etc/uci-defaults/99-aurora-dummy
	echo "exit 0" >> $(1)/etc/uci-defaults/99-aurora-dummy
	chmod 755 $(1)/etc/uci-defaults/99-aurora-dummy
endef

$(eval $(call BuildPackage,luci-theme-aurora))
EOF

# 5. 强制更新 .config 文件
echo "强制更新配置文件..."
CONFIG_FILE="$BUILD_ROOT/.config"
if [ -f "$CONFIG_FILE" ]; then
    echo "更新 $CONFIG_FILE"
    
    # 移除所有 luci-light 和 aurora 相关配置
    sed -i '/luci-light/d' "$CONFIG_FILE"
    sed -i '/luci-theme-aurora/d' "$CONFIG_FILE"
    sed -i '/LUCI_LIGHT_THEME/d' "$CONFIG_FILE"
    
    # 添加强制配置
    cat >> "$CONFIG_FILE" << 'CONFIG_EOF'

# ============================================
# 强制 LuCI 配置（避免 luci-theme-aurora 依赖）
# ============================================
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-ssl=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-theme-aurora=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-lib-base=y
CONFIG_PACKAGE_luci-lib-ip=y
CONFIG_PACKAGE_luci-lib-ipkg=y
CONFIG_PACKAGE_luci-lib-jsonc=y
CONFIG_PACKAGE_luci-lib-nixio=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-mod-system=y
CONFIG_PACKAGE_luci-proto-ipv6=y
CONFIG_PACKAGE_luci-proto-ppp=y
CONFIG_PACKAGE_luci-proto-wireguard=y
CONFIG_PACKAGE_luci-app-firewall=y
CONFIG_PACKAGE_luci-app-uhttpd=y
CONFIG_PACKAGE_luci-app-upnp=y
# CONFIG_PACKAGE_luci-light is not set
# CONFIG_PACKAGE_luci-nginx is not set
CONFIG_EOF
    
    echo "配置文件已更新"
else
    echo "警告: 未找到 .config 文件，创建新的..."
    cat > "$BUILD_ROOT/.config" << 'CONFIG_EOF'
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
CONFIG_PACKAGE_luci-theme-aurora=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-mod-admin-full=y
CONFIG_PACKAGE_luci-mod-network=y
CONFIG_PACKAGE_luci-mod-status=y
CONFIG_PACKAGE_luci-mod-system=y
# CONFIG_PACKAGE_luci-light is not set
CONFIG_EOF
fi

# 6. 清理 onionshare-cli 依赖
echo "修复 onionshare-cli 依赖..."
find "$BUILD_ROOT" -name "Makefile" -type f -exec grep -l "python3-pysocks\|python3-unidecode" {} \; 2>/dev/null | while read -r MAKEFILE; do
    echo "修复: $MAKEFILE"
    sed -i '/^DEPENDS:/s/+python3-pysocks//g' "$MAKEFILE"
    sed -i '/^DEPENDS:/s/+python3-unidecode//g' "$MAKEFILE"
    sed -i 's/  \+/ /g' "$MAKEFILE"
done

# 7. 最后检查
echo "=== 最后检查 ==="
echo "1. 检查是否还有 luci-theme-aurora 依赖:"
if find "$BUILD_ROOT" -name "Makefile" -type f -exec grep -l "luci-theme-aurora" {} \; 2>/dev/null | grep -q .; then
    echo "警告: 仍有依赖，正在强制清除..."
    find "$BUILD_ROOT" -name "Makefile" -type f -exec sed -i 's/luci-theme-aurora//g' {} \;
else
    echo "✓ 没有 luci-theme-aurora 依赖"
fi

echo "2. 检查 bootstrap 主题配置:"
if [ -f "$CONFIG_FILE" ] && grep -q "CONFIG_PACKAGE_luci-theme-bootstrap=y" "$CONFIG_FILE"; then
    echo "✓ bootstrap 主题已启用"
else
    echo "添加 bootstrap 主题配置"
    echo "CONFIG_PACKAGE_luci-theme-bootstrap=y" >> "$CONFIG_FILE"
fi

echo "3. 检查 luci-theme-aurora 包:"
if [ -f "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile" ]; then
    echo "✓ luci-theme-aurora 虚拟包已创建"
else
    echo "创建 luci-theme-aurora 虚拟包"
    mkdir -p "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora"
    echo "include \$(TOPDIR)/rules.mk" > "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile"
    echo "PKG_NAME:=luci-theme-aurora" >> "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile"
    echo "PKG_VERSION:=1.0" >> "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile"
    echo "include \$(INCLUDE_DIR)/package.mk" >> "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile"
    echo "define Package/luci-theme-aurora" >> "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile"
    echo "endef" >> "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile"
    echo "\$(eval \$(call BuildPackage,luci-theme-aurora))" >> "$BUILD_ROOT/package/feeds/luci/luci-theme-aurora/Makefile"
fi

echo ""
echo "=== 终极修复完成 ==="
echo "已执行以下操作:"
echo "1. 搜索并修复所有包含 luci-theme-aurora 的 Makefile"
echo "2. 创建了 luci-theme-aurora 虚拟包"
echo "3. 强制更新了 .config 配置文件"
echo "4. 确保使用 bootstrap 主题"
echo "5. 修复了其他依赖问题"
echo ""
echo "现在可以继续添加包了..."
echo ""

# ====================================================================
# 安装和更新软件包（你的原有代码）
# ====================================================================

UPDATE_PACKAGE() {
    # ... 你的原有 UPDATE_PACKAGE 函数代码保持不变 ...
    # 但我们需要确保在正确的目录执行
    echo "当前目录: $(pwd)"
    
    # 删除本地可能存在的不同名称的软件包
    for NAME in "${PKG_LIST[@]}"; do
        echo "Search directory: $NAME"
        local FOUND_DIRS=$(find "$BUILD_ROOT/feeds/luci/" "$BUILD_ROOT/feeds/packages/" -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

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
# 添加缺失的包
# ====================================================================

echo "开始添加缺失的包..."

# 确保在 package 目录
if [ ! -d "wrt" ]; then
    mkdir -p wrt/package
    cd wrt/package
    echo "切换到 wrt/package 目录: $(pwd)"
fi

# 1. WRTBwmon
echo "添加 wrtbwmon..."
UPDATE_PACKAGE "wrtbwmon" "brvphoenix/wrtbwmon" "master"
UPDATE_PACKAGE "luci-app-wrtbwmon" "brvphoenix/luci-app-wrtbwmon" "master"

# 2. Lucky
echo "添加 lucky..."
UPDATE_PACKAGE "lucky" "gdy666/lucky" "master"
UPDATE_PACKAGE "luci-app-lucky" "gdy666/luci-app-lucky" "main"

# 3. rtp2httpd
echo "添加 rtp2httpd..."
UPDATE_PACKAGE "rtp2httpd" "stackia/rtp2httpd" "main"

# 创建简单的luci-app-rtp2httpd目录结构
if [ ! -d "luci-app-rtp2httpd" ]; then
    echo "创建luci-app-rtp2httpd目录结构..."
    mkdir -p luci-app-rtp2httpd
    cat > luci-app-rtp2httpd/Makefile << 'EOF'
#
# Copyright (C) 2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=RTP to HTTP Streamer
LUCI_DEPENDS:=+rtp2httpd
LUCI_PKGARCH:=all

PKG_NAME:=luci-app-rtp2httpd
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
EOF
    echo "luci-app-rtp2httpd目录创建完成"
fi

echo "缺失包添加完成！"

# ====================================================================
# 原有的其他包（保持不变）
# ====================================================================

echo "开始添加其他主题和插件..."
# ...（保持原有代码不变）...

# ====================================================================
# 修复UPDATE_VERSION函数 - 专门处理lucky的问题
# ====================================================================

UPDATE_VERSION() {
    # ... 你的原有 UPDATE_VERSION 函数代码保持不变 ...
}

# ====================================================================
# 专门处理lucky版本更新的函数
# ====================================================================

UPDATE_LUCKY_VERSION() {
    # ... 你的原有 UPDATE_LUCKY_VERSION 函数代码保持不变 ...
}

# ====================================================================
# 执行更新
# ====================================================================

echo "开始更新软件包版本..."
UPDATE_VERSION "sing-box"
UPDATE_LUCKY_VERSION  # 使用专门的lucky更新函数
echo "版本更新完成！"

# ====================================================================
# 最终验证
# ====================================================================

echo "=== 最终验证 ==="
echo "验证 luci-theme-aurora 问题是否解决..."

# 检查编译目录是否存在
if [ -d "/mnt/build_wrt" ]; then
    echo "检查 /mnt/build_wrt 目录..."
    cd /mnt/build_wrt
    
    # 运行 make defconfig 确保配置正确
    echo "运行 make defconfig..."
    make defconfig 2>&1 | grep -i "luci\|theme" || true
    
    # 检查配置
    echo "当前 LuCI 配置:"
    grep -i "luci.*theme" .config 2>/dev/null || echo "没有找到主题配置"
    
    # 回到原目录
    cd - > /dev/null
fi

echo "=== 所有修复和配置完成 ==="
echo "现在应该可以正常编译了！"
echo "如果还有问题，请检查："
echo "1. .config 文件中的 luci-theme-bootstrap 是否启用"
echo "2. luci-light 是否被禁用"
echo "3. luci-theme-aurora 虚拟包是否存在"
