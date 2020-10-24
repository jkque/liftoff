#!/bin/sh
#
# This script should be run via curl:
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/tighten/init/main/tools/install.sh)"
# or via wget:
#   sh -c "$(wget -qO- https://raw.githubusercontent.com/tighten/init/main/tools/install.sh)"
# or via fetch:
#   sh -c "$(fetch -o - https://raw.githubusercontent.com/tighten/init/main/tools/install.sh)"
#
# As an alternative, you can first download the install script and run it afterwards:
#   wget https://raw.githubusercontent.com/tighten/init/main/tools/install.sh
#   sh install.sh

set -e

BIN=/usr/local/bin

define_helpers() {
    # https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh#L52
    command_exists() {
        command -v "$@" >/dev/null 2>&1
    }

    composer_has_package() {
        composer global show 2>/dev/null | grep "$@" >/dev/null
    }

    composer_require() {
        if composer_has_package "$@"; then
            echo "$@ already installed; skipping."
        else
            echo "Installing $@..."
            composer global require "$@" --quiet
            echo "$@ installed!"
        fi
    }

    php_version() {
        php -v | grep ^PHP | cut -d' ' -f2
    }

    php_version_is_acceptable() {
        php -r 'exit((int)version_compare(PHP_VERSION, "7.0.0", "<"));'
    }

    # https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh#L52
    setup_color() {
        # Only use colors if connected to a terminal
        if [ -t 1 ]; then
            RED=$(printf '\033[31m')
            GREEN=$(printf '\033[32m')
            YELLOW=$(printf '\033[33m')
            BLUE=$(printf '\033[34m')
            BOLD=$(printf '\033[1m')
            RESET=$(printf '\033[m')
        else
            RED=""
            GREEN=""
            YELLOW=""
            BLUE=""
            BOLD=""
            RESET=""
        fi
    }

    title() {
        local TITLE=$@
        echo ""
        echo "${GREEN}${TITLE}${RESET}"
        echo "============================================================"
    }

    # https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh#L60
    underline() {
        echo "$(printf '\033[4m')$@$(printf '\033[24m')"
    }
}

define_steps() {
    get_os() {
        local unameOut="$(uname -s)"
        case "${unameOut}" in
            Linux*)     OS=linux;;
            Darwin*)    OS=macos;;
            *)          OS="UNKNOWN:${unameOut}" # @todo test this on WSL2; does it report differently than Linux?
        esac
    }

    install_php() {
        title "Install PHP"

        if command_exists php; then
            if php_version_is_acceptable; then
                echo "We'll rely on your built-in PHP for now."
            else
                echo "Sorry, your built-in PHP is too old. We require 7.0 and yours is $(php_version)"
                exit
            fi
        else
            echo "Sorry, only programmed for built-in PHP so far."
            exit
        fi
    }

    # https://getcomposer.org/doc/faqs/how-to-install-composer-programmatically.md
    install_composer() {
        title "install_laravel_installer Composer"

        if command_exists composer; then
            echo "Composer already installed; skipping."
        else
            echo "Downloading Composer..."
            php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

            if command_exists curl; then
                echo "Checking validity of the downloaded file..."

                local EXPECTED_CHECKSUM="$(curl -fsSL https://composer.github.io/installer.sig)"
                local ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

                if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
                then
                    >&2 echo 'ERROR: Invalid installer checksum from Composer'
                    rm composer-setup.php
                    exit 1
                fi
            else
                echo "Can't check Composer's signature because your machine doesn't have curl."
            fi

            echo "Running Composer setup script..."
            php composer-setup.php --quiet
            RESULT=$?
            rm composer-setup.php

            local TARGET_PATH="$BIN/composer"
            mv composer.phar $TARGET_PATH

            if [ $RESULT ]; then
                echo "Composer installed!"
            else
                echo "Error installing Composer."
                exit
            fi
        fi
    }

    install_laravel_installer() {
        title "Install the Laravel Installer"
        composer_require laravel/installer
    }

    install_takeout() {
        title "Install Takeout"
        composer_require tightenco/takeout
    }

    logo() {
        echo ""
        printf "$BLUE"
        cat <<-'EOF'

    d888888b d8b   db d888888b d888888b 
      `88'   888o  88   `88'   `~~88~~' 
       88    88V8o 88    88       88    
       88    88 V8o88    88       88    
      .88.   88  V888   .88.      88    
    Y888888P VP   V8P Y888888P    YP    

        ... has set you up for Laravel!
EOF
        printf "$RESET"
    }

    # @todo: is it possible for us to manually trigger Docker installation on any machines? Assume no?
    instructions() {
        echo ""
        echo "In order for Takeout to work, you'll need to install Docker."
        echo "Here are instructions for your system:"
        echo ""
        underline "https://takeout.tighten.co/install/$OS"
        echo ""
        echo "Once you've done that, you can run 'takeout install' to install"
        echo "dependencies like MySQL."
    }
}

main() {
    define_helpers
    define_steps

    get_os
    setup_color

    install_php
    install_composer
    install_laravel_installer
    install_takeout

    logo
    instructions
}

main "$@"
