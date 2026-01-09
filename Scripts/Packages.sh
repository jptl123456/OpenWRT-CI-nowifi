#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# ====================================================================
# 只添加缺失的两个包
# ====================================================================

echo "开始添加缺失的包..."

# 1. 添加 WRTBwmon
echo "添加 wrtbwmon..."
UPDATE_PACKAGE "wrtbwmon" "brvphoenix/wrtbwmon" "master"
UPDATE_PACKAGE "luci-app-wrtbwmon" "brvphoenix/luci-app-wrtbwmon" "master"

# 2. 添加 Lucky - 修正分支问题
echo "添加 lucky..."
# 删除现有的
rm -rf lucky luci-app-lucky
# 尝试不同方式
git clone --depth=1 https://github.com/gdy666/lucky.git
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git

# 3. 添加 rtp2httpd - 重要：需要将包放在正确的位置
echo "添加 rtp2httpd 和 luci-app-rtp2httpd..."
# 删除现有的包
rm -rf rtp2httpd luci-app-rtp2httpd

# 克隆仓库
git clone --depth=1 https://github.com/stackia/rtp2httpd.git

# 从正确的目录复制包到当前目录（package/）
if [ -d "rtp2httpd/openwrt-support/rtp2httpd" ]; then
    echo "复制 rtp2httpd 包到当前目录"
    cp -rf rtp2httpd/openwrt-support/rtp2httpd ./
    echo "rtp2httpd 已添加"
fi

if [ -d "rtp2httpd/openwrt-support/luci-app-rtp2httpd" ]; then
    echo "复制 luci-app-rtp2httpd 包到当前目录"
    cp -rf rtp2httpd/openwrt-support/luci-app-rtp2httpd ./
    echo "luci-app-rtp2httpd 已添加"
fi

# 清理
rm -rf rtp2httpd/

echo "缺失包添加完成！"

# ====================================================================
# 原有的其他包（保持不变）
# ====================================================================

echo "开始添加其他主题和插件..."

# 主题
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

# 科学插件
UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "xiaorouji/openwrt-passwall2" "main" "pkg"

# 网络工具
UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"

# 其他应用
UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/luci-app-netspeedtest" "master" "" "homebox speedtest"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

echo "其他包添加完成！"

# ====================================================================
# 验证包是否正确放置
# ====================================================================

echo -e "\n验证包放置位置..."
echo "=========================================="

check_package_location() {
    local pkg=$1
    local location=$2
    if [ -d "$location/$pkg" ]; then
        echo "✓ $pkg 在 $location"
    else
        echo "✗ $pkg 不在 $location"
        # 尝试查找
        find .. -type d -name "$pkg" 2>/dev/null | head -3
    fi
}

echo "检查 rtp2httpd 相关包位置:"
check_package_location "rtp2httpd" "."
check_package_location "luci-app-rtp2httpd" "."

echo "=========================================="

# ====================================================================
# 更新软件包版本
# ====================================================================

#更新软件包版本
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
			echo "无法获取仓库信息，跳过 $PKG_FILE"
			continue
		fi
		
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

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

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

echo "开始更新软件包版本..."

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
UPDATE_VERSION "sing-box"
# UPDATE_VERSION "lucky"  # 暂时注释掉，因为API调用有问题

echo "版本更新完成！"

# ====================================================================
# 验证添加的包
# ====================================================================

echo -e "\n验证添加的包..."
echo "=========================================="

# 检查包是否添加成功
check_package() {
    local pkg=$1
    # 检查当前目录
    if [ -d "$pkg" ]; then
        echo "✓ $pkg 已添加（在当前目录）"
    # 检查其他位置
    elif find . ../feeds/ -maxdepth 3 -type d -name "*$pkg*" 2>/dev/null | grep -q .; then
        echo "✓ $pkg 已添加"
    else
        echo "✗ $pkg 未找到"
    fi
}

echo "检查缺失的包:"
check_package "wrtbwmon"
check_package "luci-app-wrtbwmon"
check_package "lucky"
check_package "luci-app-lucky"
check_package "rtp2httpd"
check_package "luci-app-rtp2httpd"

echo "=========================================="
echo "Packages.sh 脚本执行完成！"
echo "=========================================="

# ====================================================================
# 最后的重要步骤
# ====================================================================

echo -e "\n重要提示："
echo "1. rtp2httpd 和 luci-app-rtp2httpd 已添加到当前目录"
echo "2. 请确保您的配置中有以下设置："
echo "   CONFIG_PACKAGE_rtp2httpd=y"
echo "   CONFIG_PACKAGE_luci-app-rtp2httpd=y"
echo "3. 如果需要，运行以下命令更新 feeds："
echo "   cd .. && ./scripts/feeds update -a && ./scripts/feeds install -a"
echo "=========================================="
