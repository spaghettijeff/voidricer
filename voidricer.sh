#!/bin/bash

while getopts "p:d:s:h" o; do case "${o}" in
    h) printf "Optional arguments:\\n\
        -h: display this help message\\n\
        -d: git repo for dotfiles. url or local, default https://github.com/spaghettijeff/dotfiles\\n\
        -p: package list. url or local, default https://jeffreybutler.net/pkglist\\n\
        -s: source dir. directory where source based programms will exist, default /usr/local/src/" && exit 1 ;;
    d) dotfile_repo=${OPTARG} ;;
    p) pkglist=${OPTARG} ;;
    s) srcdir=${OPTARG} ;;
    *) printf "Invalid arguments\\n" && exit 1 ;;
esac done

# Setting default values
[ -z ${doftile_repo} ] && dotfile_repo="https://github.com/spaghettijeff/dotfiles"
[ -z ${pkglist} ] && pkglist="jeffreybutler.net/pkglist.txt"
[ -z ${srcdir} ] && srcdir="/usr/local/src"


error() { printf "$1\\n" && exit 1 ; }

pkgmanager() { \
    xbps-install -y "$1" 
}

gitinstall() { \
    mkdir -p "$srcdir/$1"
    git clone "$2" "$srcdir/$1" || error "git failed to clone $1 from $2"
    make --directory="$srcdir/$1" clean install || error "make failed to install $1"
}

autoinstall() { \
    ( [ -f "$pkglist" ] && cp "$pkglist" /tmp/pkglist.txt ) || ( curl -L "$pkglist" > /tmp/pkglist.txt || error "Failed to fetch list of packages from $pkglist" ) 
    while read -r tag pkg option; do
        case $tag in 
            "#pkg") pkgmanager "$pkg" ;;
            "#git") gitinstall "$pkg" "$option" ;;
        esac
    done < /tmp/pkglist.txt ;
}


preinstall() {\
    ( printf "Syncing local repo with remote\\n" && xbps-install -Syu ) || error "Could not run xbps-install. Are you running Void Linux and logged in as root?" ;
    printf "Installing dependencies for this script...\\n"
    for dep in curl git stow; do
        pkgmanager "$dep" ;
    done 
}

get_user_pass() {\
    read -p "would you like to add a new user account (y/n)? " newuser
    case "${newuser}" in
        y|Y) 
            read -p "Username: " username ;
            # TODO chekc if valid username
            read -sp "Password: " userpass1 ;
            # TODO check if valid password
            echo
            read -sp "Re-enter Password: " userpass2 ;
            echo

            while ! [ "$userpass1" = "$userpass2" ]; do
                unset userpass2 ;
                read -sp "Passwords do not match. Enter password again: " userpass1
                echo
                read -sp "Re-enter Password: " userpass2 
                echo
                # TODO validation down here too
            done ;
            ;;
        *) 
            printf "Skipping creation of new user account.\\n" ;;
    esac
    if [[ $(id -u "$username") ]] ; then
        printf "Warning the user $username already exists on this device!\\n"
        read -p "would you like to continue with the user $username and overwrite any existing config files (y/n)? " overwrite
            case "$overwrite" in
                y|Y)  usermod -a -G wheel "$username" && mkdir -p /home/"$username" && chown "$username":wheel /home/"$username" ;;
                *) printf "The user $username will not be configured" && unset username ;;
            esac
    fi
}

create_user() {\
    useradd -m -g wheel -s /bin/zsh "$username" > /dev/null 
    printf "New user $username created.\\n"
} 

deploy_dotfiles() {\
    printf "Deploying dotfiles for user $username.\\n"
    if [[ ! -d "${dotfile_repo}" ]] ; then
        git clone "${dotfile_repo}" "/home/${username}/.dotfiles" || error "Failed to clone"
        chown -R "$username":wheel "/home/${username}/.dotfiles"
        dotfile_repo="/home/${username}/.dotfiles"
    fi
    cwd=$dir
    cd "$dotfile_repo"
    for conf in ${dotfile_repo}/* ; do
        conf=${conf#"$dotfile_repo/"}
        printf "Symlinking $conf config files.\\n"
        sudo -u "$username" stow -S "$conf"
    done
    cd "$cwd"
}

# Actuall installation
get_user_pass ;
preinstall ;
autoinstall ;
! [ -z ${username} ] && create_user && deploy_dotfiles  ;
exit 0 ;
