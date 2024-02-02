clear

print() {
    echo
    echo ">>> $1"
    echo
}

prompt_confirm() {
    print "$1"
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

get_ssh_port() {
    echo $(grep "Port " /etc/ssh/sshd_config | awk '{print $2}')
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
    
    print "RESULT:"
    grep "PermitRootLogin" /etc/ssh/sshd_config
    
    prompt_continue
fi
clear

#
# change ssh port
#
prompt_yes_no "Change ssh port?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    read -p "new ssh port: " new_ssh_port
    sed -i "s/#Port 22/Port $new_ssh_port/" /etc/ssh/sshd_config
    systemctl restart ssh
    
    print "RESULT:"
    systemctl status ssh | grep "Loaded:"
    systemctl status ssh | grep "Active:"
    systemctl status ssh | grep "port"
    grep "Port " /etc/ssh/sshd_config
    
    prompt_continue
fi
clear

#
# nftables
#
prompt_yes_no "Setup nftables?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    print "Setting up nftables..."
    apt purge iptables
    apt autoremove --purge
    apt install nftables
    systemctl enable nftables
    systemctl start nftables
    nft flush ruleset
    wget https://raw.githubusercontent.com/leonb033/debian_server_setup/main/nftables.conf
    sed -i "s/SSH_PORT/$(get_ssh_port)/" nftables.conf
    mv -f nftables.conf /etc/nftables.conf
    systemctl restart nftables
    
    print "RESULT:"
    systemctl status nftables | grep "Loaded:"
    systemctl status nftables | grep "Active:"
    nft list ruleset
    
    prompt_continue
fi
clear

#
# fail2ban
#
prompt_yes_no "Setup fail2ban?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    print "Setting up fail2ban..."
    apt install fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i "s/port    = ssh/port    = $(get_ssh_port)/" /etc/fail2ban/jail.local
    sed -i "s/port     = ssh/port    = $(get_ssh_port)/" /etc/fail2ban/jail.local
    sed -i "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
    if systemctl is-active --quiet [nftables]; then
        sed -i "s/banaction = iptables-multiport/banaction = nftables/" /etc/fail2ban/jail.local
        sed -i "s/banaction_allports = iptables-allports/banaction_allports = nftables[type=allports]/" /etc/fail2ban/jail.local
    fi
    systemctl restart fail2ban
    
    print "RESULT:"
    systemctl status fail2ban | grep "Loaded:"
    systemctl status fail2ban | grep "Active:"
    grep -A 25 "SSH servers" /etc/fail2ban/jail.local | grep "port"
    grep -A 20 '"backend"' /etc/fail2ban/jail.local | grep "backend ="
    grep -A 6 "Default banning action" /etc/fail2ban/jail.local | grep "="
    
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
