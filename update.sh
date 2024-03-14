# clean apt cache
apt clean -y
# search for package updates
apt update
# install available package updates
apt upgrade -y
# delete unused dependency packages
apt autoremove --purge -y
# reboot
systemctl reboot
