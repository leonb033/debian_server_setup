clear

ssh_port=-1

prompt_confirm() {
    echo $1
    read
}

prompt_continue() {
    echo
    prompt_confirm "Finished. Press enter to continue."
}

prompt_yes_no() {
    while true; do
        read -p "$1 (y/n): "
        if [[ $REPLY =~ ^[yY]$ || $REPLY =~ ^[nN]$ ]]; then break; fi
    done
}

#
# update system
#
prompt_yes_no "Update system?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    apt update
    apt upgrade
    apt autoremove --purge
    apt clean
    
    prompt_continue
fi
clear

#
# change root password
#
prompt_yes_no "Change root password?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    passwd root
    
    prompt_continue
fi
clear

#
# create sudo user
#
prompt_yes_no "Create sudo user?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    apt install sudo
    read -p "sudo user name: " sudo_name
    adduser $sudo_name
    usermod -aG sudo $sudo_name
    
    prompt_continue
fi
clear

#
# disable root ssh
#
prompt_yes_no "Disable root ssh?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
    systemctl restart ssh
    
    echo
    echo "RESULT:"
    cat /etc/ssh/sshd_config | grep "PermitRootLogin"
    
    prompt_continue
fi
clear

#
# change ssh port
#
prompt_yes_no "Change ssh port?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    read -p "new ssh port: " ssh_port
    sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
    systemctl restart ssh
    systemctl status ssh
    
    echo
    echo "RESULT:"
    cat /etc/ssh/sshd_config | grep "Port "
    
    prompt_continue
fi
clear

#
# nftables
#
prompt_yes_no "Setup nftables?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    echo "Setting up nftables..."
    if [[ $ssh_port -eq -1 ]]; then
        read -p "current ssh port: " ssh_port
    fi
    apt purge iptables
    apt autoremove --purge
    apt install nftables
    systemctl enable nftables
    systemctl start nftables
    nft flush ruleset
    wget https://raw.githubusercontent.com/leonb033/debian_server_setup/main/nftables.conf
    sed -i "s/SSH_PORT/$ssh_port/" nftables.conf
    mv -f nftables.conf /etc/nftables.conf
    systemctl restart nftables
    systemctl status nftables
    echo
    echo "RESULT:"
    nft list ruleset
    
    prompt_continue
fi
clear

#
# fail2ban
#
prompt_yes_no "Setup fail2ban?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    echo "Setting up fail2ban..."
    if [[ $ssh_port -eq -1 ]]; then
        read -p "current ssh port: " ssh_port
    fi
    apt install fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i "s/port    = ssh/port    = $ssh_port/" /etc/fail2ban/jail.local
    sed -i "s/port     = ssh/port    = $ssh_port/" /etc/fail2ban/jail.local
    sed -i "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
    if systemctl is-active --quiet [service_name]; then
        echo "RUNNING"
        sed -i "s/banaction = iptables-multiport/banaction = nftables/" /etc/fail2ban/jail.local
        sed -i "s/banaction_allports = iptables-allports/banaction_allports = nftables[type=allports]/" /etc/fail2ban/jail.local
    else:
        echo "NOT RUNNING"
    fi
    systemctl restart fail2ban
    systemctl status fail2ban
    
    echo
    echo "RESULT:"
    echo "SSH ports:"
    cat /etc/fail2ban/jail.local | grep -A 25 "SSH servers" | grep "port"
    echo "Backend:"
    cat /etc/fail2ban/jail.local | grep -A 20 '"backend"' | grep "backend ="
    
    prompt_continue
fi
clear

#
# utilities
#
prompt_yes_no "Install utility packages?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    apt install tree
    apt install locate
    apt install unzip
    apt install btop
    apt install micro
    
    prompt_continue
fi
clear

#
# reboot
#
prompt_yes_no "Reboot system?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    systemctl reboot
fi
