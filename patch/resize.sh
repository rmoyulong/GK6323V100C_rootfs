chown root:root /etc/sudo.conf /etc/sudoers
chown -R root:root /etc/sudoers.d

chown root:root /usr/bin/sudo
chmod 4755 /usr/bin/sudo


resize2fs /dev/mmcblk0p18

sudo chown squeezeboxserver:nogroup /var/lib/squeezeboxserver/prefs
sudo chown -R squeezeboxserver:nogroup /var/lib/squeezeboxserver/cache
sudo chown -R squeezeboxserver:nogroup /var/log/squeezeboxserver


sudo systemctl restart  lyrionmusicserver
