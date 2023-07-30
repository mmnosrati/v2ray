#!/bin/bash
#edited by MMNSTUDIO : t.me/mmnstudio

#Used Colors and other decoration
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
bold=$(tput bold)
#

# Check root
#[[ $EUID -ne 0 ]] && echo -e "${red}${bold}mistake:${plain} This script must be run with the root user！\n" && exit 1
#

# Check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif sudo cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif sudo cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif sudo cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif sudo cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif sudo cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif sudo cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}${bold}The operating system distribution was not detected！${plain}\n" && exit 1
fi
#

# Checking architecture
arch=$(sudo arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    echo -e "${red}Architecture not detected, (amd64) is used by default.
 ${arch}${plain}"
    arch="amd64"
fi
#

# Checking that the system is 64-bit
if [ $(sudo getconf WORD_BIT) != '32' ] && [ $(sudo getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit system (x86), please use 64-bit system (x86_64)"
    exit -1
fi
#

# Checking distributions version limit
os_version=""
if [[ -f /etc/os-release ]]; then
    os_version=$(sudo awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(sudo awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or later system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later system！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later！${plain}\n" && exit 1
    fi
fi
#

#Install the necessary packages
install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        sudo yum install wget curl socat tar -y
    else
        sudo apt install wget curl socat tar -y
    fi
}
#

#This function will be called when user installed x-ui out of security
config_after_install() {
    echo -e "${yellow}${bold}For security reasons :" 
    echo -e "port and account passwords must be changed after installation/update${plain}"
    read -p "${bold}Confirm to continue? [y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow}Your account password will be set to:${config_password}${plain}"
        read -p "Please set the panel access port:" config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}Confirm setting, setting${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}The account password is set${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}Panel port setting completed.${plain}"
    else
        echo -e "${red}Canceled, all setting items are default settings, please correct in time.${plain}"
    fi
}

install_x-ui() {
    sudo systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(sudo curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Failed to detect the x-ui version, it may be beyond the limit${plain}"
            echo -e "${red}of Github API, please try again later${plain}"
            echo -e "${red}or manually specify the x-ui version to install${plain}"
            exit 1
        fi
        echo -e "Detected the latest version of x-ui：${last_version},start installation..."
        sudo wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download x-ui failed, please make sure your server${plain}"
            echo -e "${red}can download files from Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
        echo -e "Start installing x-ui version $1"
        sudo wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Download x-ui v$1 failed, make sure this version exists ${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        sudo rm /usr/local/x-ui/ -rf
    fi

    sudo tar zxvf x-ui-linux-${arch}.tar.gz
    sudo rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    sudo chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    sudo wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/vaxilu/x-ui/main/x-ui.sh
    sudo chmod +x /usr/local/x-ui/x-ui.sh
    sudo chmod +x /usr/bin/x-ui
    config_after_install
    echo -e "${yellow}If it is a fresh installation, the default web port is ${green}54321${plain}"
    echo -e "${yellow}and the default username and password are ${green}admin${plain}"
    echo -e "${yellow}Please ensure that this port is not occupied by other programs${plain}"
    echo -e "${yellow}and ensure that port 54321 has been released.${plain}"
    echo -e "${yellow}If you want to modify 54321 to another port, enter the x-ui command to modify,${plain}"
    echo -e "${yellow}and also make sure that the port you modified is also allowed.${plain}"
    echo -e ""
    echo -e "If you update the panel, you will access the panel as you did before"
    echo -e ""
    sudo systemctl daemon-reload
    sudo systemctl enable x-ui
    sudo systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} The installation is complete and the panel is activated，"
    echo -e ""
    echo -e "x-ui How to use the management script: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Show admin menu (more features)"
    echo -e "x-ui start        - Start the x-ui panel"
    echo -e "x-ui stop         - Stop x-ui panel"
    echo -e "x-ui restart      - Restart the x-ui panel"
    echo -e "x-ui status       - View x-ui status"
    echo -e "x-ui enable       - Set x-ui to start automatically at boot"
    echo -e "x-ui disable      - Cancel x-ui autostart"
    echo -e "x-ui log          - View x-ui logs"
    echo -e "x-ui v2-ui        - Migrate the v2-ui account data of this machine to x-ui
"
    echo -e "x-ui update       - Update x-ui panel"
    echo -e "x-ui install      - Install the x-ui panel"
    echo -e "x-ui uninstall    - Uninstall the x-ui panel"
    echo -e "----------------------------------------------"
}

my_public_ip = wget -qO - icanhazip.com
echo -e "${green}${bold}Start installation...${plain}"
install_base
install_x-ui $1
