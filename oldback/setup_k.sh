dd if=boot.img of=/dev/mmcblk0p15 bs=1M conv=fsync
tar xzf modules.tar.gz -C /
sync && reboot
