STOW_DIR  := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
TARGET    := $(HOME)
PACKAGES  := $(notdir $(wildcard $(STOW_DIR)/*/))

.PHONY: help stow unstow restow adopt check verify list pkglist backup deps clean purge hooks install all

## 默认: stow 所有包
all: hooks stow

## 显示帮助
help:
	@echo "用法: make [target] [PKG=<包名>]"
	@echo ""
	@echo "部署:"
	@echo "  stow       创建符号链接 (默认)"
	@echo "  unstow     移除符号链接"
	@echo "  restow     重新创建符号链接"
	@echo "  adopt      用本地文件覆盖仓库配置"
	@echo ""
	@echo "维护:"
	@echo "  check      检查冲突文件"
	@echo "  verify     验证符号链接完整性"
	@echo "  list       列出所有可管理的包"
	@echo "  update     拉取 submodule 更新"
	@echo "  submodule  初始化并更新 submodule"
	@echo "  pkglist    导出当前系统安装的包列表"
	@echo "  clean      清理临时文件"
	@echo "  purge      删除包列表备份"
	@echo "  hooks      安装 git hooks"
	@echo "  install    完整安装 (submodule + stow + hooks)"

## 列出所有包
list:
	@for p in $(PACKAGES); do echo "  $$p"; done

## 初始化 submodule (nvim)
submodule:
	@if [ -f .gitmodules ]; then git submodule update --init --recursive; fi

## 更新 submodule
update: submodule
	@if [ -f .gitmodules ]; then git submodule update --remote --recursive; fi

## 创建符号链接
stow: submodule
	@if [ "$(PKG)" ]; then \
		stow -v -d $(STOW_DIR) -t $(TARGET) -S $(PKG); \
	else \
		for p in $(PACKAGES); do \
			echo "==> stow $$p"; \
			stow -v -d $(STOW_DIR) -t $(TARGET) -S $$p 2>/dev/null || true; \
		done; \
	fi

## 移除符号链接
unstow:
	@if [ "$(PKG)" ]; then \
		stow -v -d $(STOW_DIR) -t $(TARGET) -D $(PKG); \
	else \
		for p in $(PACKAGES); do \
			stow -v -d $(STOW_DIR) -t $(TARGET) -D $$p || echo "warning: $$p 未链接，跳过"; \
		done; \
	fi

## 重新链接
restow: unstow stow

## 用本地文件覆盖仓库配置 (首次收集或迁移时使用)
adopt:
	@if [ "$(PKG)" ]; then \
		stow -v --adopt -d $(STOW_DIR) -t $(TARGET) -S $(PKG); \
		echo "检查 git diff $(PKG) 查看本地改动"; \
	else \
		for p in $(PACKAGES); do \
			stow -v --adopt -d $(STOW_DIR) -t $(TARGET) -S $$p; \
		done; \
		echo "所有包已采纳，使用 git diff 检查差异"; \
	fi

## 检查冲突
check:
	@if [ "$(PKG)" ]; then \
		stow -n -v -d $(STOW_DIR) -t $(TARGET) -S $(PKG); \
	else \
		for p in $(PACKAGES); do \
			stow -n -v -d $(STOW_DIR) -t $(TARGET) -S $$p; \
		done; \
	fi

## 验证符号链接完整性
verify:
	@broken=0; \
	for p in $(PACKAGES); do \
		if [ ! -d "$$p" ]; then continue; fi; \
		while IFS= read -r f; do \
			target="$(TARGET)/$$f"; \
			if [ ! -L "$$target" ]; then \
				echo "  缺失: $$target"; \
				broken=$$((broken + 1)); \
			elif [ ! -e "$$target" ]; then \
				echo "  悬空: $$target -> $$(readlink $$target)"; \
				broken=$$((broken + 1)); \
			fi; \
		done < <(cd $$p && find . -type f -not -name ".stow-local-ignore"); \
	done; \
	if [ $$broken -eq 0 ]; then \
		echo "[+] 所有符号链接健康"; \
	else \
		echo "[-] 发现 $$broken 个问题链接，运行 make restow 修复"; \
		exit 1; \
	fi

## 导出当前系统安装的包列表
pkglist:
	pacman -Qqet > $(STOW_DIR)/pkglist.txt
	@echo "[+] $(STOW_DIR)/pkglist.txt"

## 从包列表安装软件
deps:
	@if [ -f $(STOW_DIR)/pkglist.txt ]; then \
		sudo pacman -S --needed - < $(STOW_DIR)/pkglist.txt; \
	else \
		echo "[-] pkglist.txt 不存在，请先执行 make pkglist"; \
	fi

## 移除孤儿包
backup: pkglist
	@echo "[+] 备份完成"

## 清理临时文件
clean:
	find $(STOW_DIR) -type f \( -name "*.swp" -o -name "*.bak" -o -name "*~" \) -delete
	@find $(STOW_DIR) -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

## 删除包列表备份
purge:
	rm -f $(STOW_DIR)/pkglist.txt

## 安装 git hooks
hooks:
	@for hook in $(STOW_DIR)/scripts/hooks/*; do \
		name=$$(basename $$hook); \
		cp $$hook $(STOW_DIR)/.git/hooks/$$name; \
		chmod +x $(STOW_DIR)/.git/hooks/$$name; \
		echo "  installed .git/hooks/$$name"; \
	done

## 完整安装
install: submodule hooks stow
