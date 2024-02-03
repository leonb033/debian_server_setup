clear

print_message() {
    echo
    echo ">>> $1"
    echo
}

prompt_confirm() {
    print_message "$1"
    read
}

prompt_continue() {
    prompt_confirm "Finished. Press enter to continue."
}

prompt_yes_no() {
    while true; do
        read -p "$1 (y/n): "
        if [[ $REPLY =~ ^[yY]$ || $REPLY =~ ^[nN]$ ]]; then break; fi
    done
}

# returns the current ssh port
get_ssh_port() {
    echo $(grep "Port " /etc/ssh/sshd_config | awk '{print $2}')
}

# replaces a string inside a file
# param 1: old string
# param 2: new string
# param 3: path to file
replace_string() {
    sed -i "s/$1/$2/" $3
}

# replaces a line inside a file
# param 1: pattern to match old line
# param 2: content of new line
# param 3: path to file
replace_line() {
    sed -i "/$1/c\\$2" $3
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
    replace_line "PermitRootLogin " "PermitRootLogin no" /etc/ssh/sshd_config
    #sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
    systemctl restart ssh
    
    print_message "RESULT:"
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
    replace_line "Port " "Port $new_ssh_port" /etc/ssh/sshd_config
    #sed -i "s/#Port 22/Port $new_ssh_port/" /etc/ssh/sshd_config
    systemctl restart ssh
    
    print_message "RESULT:"
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
    print_message "Setting up nftables..."
    apt purge iptables
    apt autoremove --purge
    apt install nftables
    systemctl enable nftables
    systemctl start nftables
    nft flush ruleset
    wget -O nftables.conf https://raw.githubusercontent.com/leonb033/debian_server_setup/main/nftables.conf
    replace_string "SSH_PORT" $(get_ssh_port) nftables.conf
    #sed -i "s/SSH_PORT/$(get_ssh_port)/" nftables.conf
    mv -f nftables.conf /etc/nftables.conf
    systemctl restart nftables
    
    print_message "RESULT:"
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
    print_message "Setting up fail2ban..."
    apt install fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    touch /etc/fail2ban/fail2ban.local
    wget -O jail.local https://raw.githubusercontent.com/leonb033/debian_server_setup/main/jail.local
    replace_line "port    = " "port    = $(get_ssh_port)" jail.local
    if systemctl is-active --quiet nftables; then
        replace_line "banaction = " "banaction = nftables" jail.local
        replace_line "banaction_allports = " "banaction_allports = nftables[type=allports]" jail.local
    fi
    mv -f jail.local /etc/fail2ban/jail.local
    systemctl restart fail2ban
    
    print_message "RESULT:"
    systemctl status fail2ban | grep "Loaded:"
    systemctl status fail2ban | grep "Active:"
    grep -A 25 "SSH servers" /etc/fail2ban/jail.local | grep "port"
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
