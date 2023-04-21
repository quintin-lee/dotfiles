#!/bin/bash

WORKDIR="$HOME"
GITHUB_URL=https://github.com

# Options
ZSH=false
TMUX=false

# zsh 插件列表
ZSH_PLUGINS="
    zsh-users/zsh-autosuggestions
    zsh-users/zsh-syntax-highlighting.git
    unixorn/fzf-zsh-plugin.git
"

usage()
{
    printf "%s\n" \
        "usage: $0"

    printf "%s\n" \
      "-z, --zsh     Download and install dependencies of zsh"

    printf "%s\n" \
      "-t, --tmux     Download and install dependencies of tmux"

    printf "%s\n" \
      "-d, --dest    Use a directory different than $HOME"

    printf "%s\n" \
      "-h, --help    Display this help"
}

banner()
{
  printf "%s\n" \
    '
             _       _    __ _ _           
          __| | ___ | |_ / _(_) | ___  ___ 
         / _` |/ _ \| __| |_| | |/ _ \/ __|
        | (_| | (_) | |_|  _| | |  __/\__ \
         \__,_|\___/ \__|_| |_|_|\___||___/
                                     
    '
}

parse_params()
{
    while [ "$#" -gt 0 ] ; do
        case "$1" in
            -d | --dest)
                WORKDIR="$2"
                shift
                shift
                ;;
            -z | --zsh)
                ZSH=true
                shift
                ;;
            -t | --tmux)
                TMUX=true
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                usage
                printf "\\n%s\\n" "$0: Invalid option '$1'"
                exit 1
                ;;
        esac
    done
}

die()
{
    echo "[-] $1"; exit 1;
    
}

anim()
{
    while :; do
        printf "%s\b" '/'
        sleep 0.1
        printf "%s\b" '-'
        sleep 0.1
        printf "%s\b" '\'
        sleep 0.1
        printf "%s\b" '|'
        sleep 0.1
    done
}

# Download with git ( arg1 = url | arg2 = path )
dl()
{
    printf "%s " "dll $1..."
    anim &
    pid="$!"
    git clone "$1" "$2" 2>/dev/null || exit 1
    # Kill anim()
    kill -9 "$pid" >/dev/null 2>&1
    printf "%s\n" "[Ok]"
}

# Check if file exist else download ( arg1 = url | arg2 = path )
chk()
{
  [ -d "$2" ] || dl "$1" "$2"
}

install_zsh()
{
    OH_MY_ZSH="$WORKDIR"/.oh-my-zsh 

    [ -d "$OH_MY_ZSH" ] && {
        read -p "Clearing oh-my-zsh for updates? [y/n] "
            if [[ "$REPLY" =~ ^y|^Y ]] ; then
                rm -rf "$OH_MY_ZSH"
            else
                echo "Ok, we keep your directory..."
                return
            fi
    }

    chk ${GITHUB_URL}/ohmyzsh/ohmyzsh "$OH_MY_ZSH"

    for plugin in ${ZSH_PLUGINS[@]}
    do
        URL=${GITHUB_URL}/${plugin}
        PLUGIN_NAME=$(echo ${plugin} | awk -F"/" '{print $2}' | awk -F'.' '{print $1}')
        PLUGIN_PATH=${OH_MY_ZSH}/custom/plugins/${PLUGIN_NAME}

        chk ${URL} "${PLUGIN_PATH}"
    done
}

main()
{
    parse_params $@
    banner

    $ZSH && install_zsh

    echo "[+] Bye"
}

main $@
