sudo dd if=bootloader.PARTITION of=u-boot.bin bs=512 skip=1


sudo dd if=u-boot.bin of=/dev/sda conv=fsync,notrunc bs=1 count=444
sudo dd if=u-boot.bin of=/dev/sda conv=fsync,notrunc bs=512 skip=1 seek=1
sync