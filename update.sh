set -x

# clean apt cache
apt clean -y
echo

# search for package updates
apt update
echo

# install available package updates
apt upgrade -y
echo

# delete unused dependency packages
apt autoremove --purge -y
echo

# reboot
systemctl reboot
