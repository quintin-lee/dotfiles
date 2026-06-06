# ~/.config/zsh/xdg.sh — 统一 XDG Base Directory 规范
# 在 .zshrc 顶部 source

# 显式导出 XDG 变量 (如未设置则使用默认值)
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# 确保目录存在
_mkdir_xdg() {
    [ -d "$1" ] || mkdir -p "$1"
}
_mkdir_xdg "$XDG_STATE_HOME/zsh"
_mkdir_xdg "$XDG_CACHE_HOME/zsh"

# zsh 历史
export HISTFILE="$XDG_STATE_HOME/zsh/history"
export HISTSIZE=10000
export SAVEHIST=10000

# zsh 补全缓存目录
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompcache"

# fcitx5 缓存
export FCITX5_CACHE_DIR="$XDG_CACHE_HOME/fcitx5"
_mkdir_xdg "$FCITX5_CACHE_DIR"

# ranger (默认已 XDG 兼容，显式声明便于备份)
export RANGER_DATA_DIR="$XDG_DATA_HOME/ranger"
export RANGER_STATE_DIR="$XDG_STATE_HOME/ranger"
_mkdir_xdg "$RANGER_STATE_DIR"
