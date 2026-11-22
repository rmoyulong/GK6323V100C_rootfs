sudo dd if=u-boot.bin.sd.bin of=/dev/sda conv=fsync bs=1 count=442
sudo dd if=u-boot.bin.sd.bin of=/dev/sda conv=fsync bs=512 skip=1 seek=1
sync