tar -xzf modules.tar.gz && sync
dd if=boot.img of=/dev/mmcblk0p15 bs=1M conv=fsync
#dd if=gk6323v100c-chaoge-z71a.dtb of=/dev/mmcblk0p10 bs=1K conv=fsync
#dd if=/dev/mmcblk0p10 of=dtbo.new.img bs=1M conv=fsync
sync