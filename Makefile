STOW_DIR  := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
TARGET    := $(HOME)
PACKAGES  := $(notdir $(wildcard $(STOW_DIR)/*/))

# 包分组
GUI_PKGS  := sway swaylock waybar kitty hypr
CLI_PKGS  := zsh tmux ranger nvim
IM_PKGS   := fcitx5
TOOL_PKGS := git

.PHONY: help stow unstow restow adopt check verify list pkglist backup deps clean purge hooks install all
.PHONY: stow-gui stow-cli stow-im stow-tool xdg-backup xdg-restore

## 默认: 安装所有
all: hooks stow

## 显示帮助
help:
	@echo "用法: make [target] [PKG=<包名>]"
	@echo ""
	@echo "部署 (单包):"
	@echo "  stow       创建符号链接"
	@echo "  unstow     移除符号链接"
	@echo "  restow     重新创建符号链接"
	@echo "  adopt      用本地文件覆盖仓库配置"
	@echo ""
	@echo "部署 (按组):"
	@echo "  stow-gui   部署 GUI 应用 $(GUI_PKGS)"
	@echo "  stow-cli   部署 CLI 工具 $(CLI_PKGS)"
	@echo "  stow-im    部署输入法   $(IM_PKGS)"
	@echo "  stow-tool  部署开发工具 $(TOOL_PKGS)"
	@echo ""
	@echo "维护:"
	@echo "  check      检查冲突文件"
	@echo "  verify     验证符号链接完整性"
	@echo "  list       列出所有可管理的包"
	@echo "  update     拉取 submodule 更新"
	@echo "  submodule  初始化并更新 submodule"
	@echo "  pkglist    导出当前系统安装的包列表"
	@echo "  deps       从 pkglist.txt 安装软件"
	@echo "  clean      清理临时文件"
	@echo "  purge      删除包列表备份"
	@echo "  hooks      安装 git hooks"
	@echo "  install    完整安装 (submodule + stow + hooks)"
	@echo "  xdg-backup  备份 XDG 状态/历史到当前目录"
	@echo "  xdg-restore 从当前目录恢复 XDG 状态/历史"

## 列出所有包
list:
	@echo "GUI:  $(GUI_PKGS)"
	@echo "CLI:  $(CLI_PKGS)"
	@echo "IM:   $(IM_PKGS)"
	@echo "TOOL: $(TOOL_PKGS)"

## 初始化 submodule (nvim)
submodule:
	@if [ -f .gitmodules ]; then git submodule update --init --recursive; fi

## 更新 submodule
update: submodule
	@if [ -f .gitmodules ]; then git submodule update --remote --recursive; fi

## 共用 stow 函数: 对一组包执行 stow
# 用法: $(call stow-group,目标名,包列表)
define stow-group
	@for p in $(2); do \
		if [ -d "$(STOW_DIR)/$$p" ]; then \
			echo "  ==> $(1): $$p"; \
			stow -d $(STOW_DIR) -t $(TARGET) -S $$p 2>/dev/null || echo "    (跳过,可能已链接)"; \
		fi; \
	done
endef

## 创建符号链接
stow: submodule
	$(call stow-group,stow,$(PACKAGES))

## 按组部署
stow-gui: submodule
	$(call stow-group,stow-gui,$(GUI_PKGS))

stow-cli: submodule
	$(call stow-group,stow-cli,$(CLI_PKGS))

stow-im:
	$(call stow-group,stow-im,$(IM_PKGS))

stow-tool:
	$(call stow-group,stow-tool,$(TOOL_PKGS))

## 移除符号链接
unstow:
	@for p in $(PACKAGES); do \
		stow -d $(STOW_DIR) -t $(TARGET) -D $$p || echo "  未链接: $$p"; \
	done

## 重新链接
restow: unstow stow

## 用本地文件覆盖仓库配置 (首次收集或迁移时使用)
adopt:
	@for p in $(PACKAGES); do \
		stow --adopt -d $(STOW_DIR) -t $(TARGET) -S $$p || true; \
	done
	@echo "[+] 完成，使用 git diff 检查差异"

## 检查冲突
check:
	@for p in $(PACKAGES); do \
		stow -n -v -d $(STOW_DIR) -t $(TARGET) -S $$p 2>&1; \
	done

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

## 备份
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

## 备份 XDG 状态目录 (history 等) 到仓库外的临时位置
xdg-backup:
	@mkdir -p /tmp/dotfiles-xdg-backup/state/zsh
	@mkdir -p /tmp/dotfiles-xdg-backup/cache
	@cp -u ~/.local/state/zsh/history /tmp/dotfiles-xdg-backup/state/zsh/ 2>/dev/null || true
	@echo "[+] 备份到 /tmp/dotfiles-xdg-backup/"

## 恢复 XDG 状态
xdg-restore:
	@mkdir -p ~/.local/state/zsh
	@cp -u /tmp/dotfiles-xdg-backup/state/zsh/history ~/.local/state/zsh/ 2>/dev/null || true
	@echo "[+] 恢复完成"
