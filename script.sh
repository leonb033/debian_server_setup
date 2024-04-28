clear

prefix=">>>"

print_message() {
    echo
    echo "$prefix $1"
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
        read -p "$prefix $1 (y/n): "
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

# creates a cronjob
create_cronjob() {
    crontab -l | { cat; echo "$1"; } | crontab -
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
prompt_yes_no "Disable root ssh login?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    replace_line "PermitRootLogin " "PermitRootLogin no" /etc/ssh/sshd_config
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
# ufw
#
prompt_yes_no "Set up ufw?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    print_message "Setting up ufw..."
    
    apt install ufw
    ufw default allow outgoing
    ufw default deny incoming
    ufw allow $(get_ssh_port)/tcp
    ufw enable

    print_message "RESULT:"
    ufw status
    
    prompt_continue
fi
clear

#
# fail2ban
#
prompt_yes_no "Set up fail2ban?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    print_message "Setting up fail2ban..."
    
    apt install fail2ban
    touch /etc/fail2ban/fail2ban.local
    #wget -O jail.local https://raw.githubusercontent.com/leonb033/debian_server_setup/main/jail.local
    replace_line "port    = " "port    = $(get_ssh_port)" jail.local
    mv -f jail.local /etc/fail2ban/jail.local
    systemctl enable fail2ban
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
# daily updates
#
prompt_yes_no "Set up daily updates?"
if [[ $REPLY =~ ^[yY]$ ]]; then
    print_message "Setting up daily updates..."

    read -p "update time (hour): " update_hour
    read -p "update time (minute): " update_minute

    mv ./update.sh ~/update.sh
    touch ~/update.log
    chmod 700 ~/update.sh ~/update.log
    create_cronjob "$update_minute $update_hour * * * bash ~/update.sh > ~/update.log"
    
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
    apt install net-tools
    apt install btop
    apt install micro
    apt install nmap
    
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
