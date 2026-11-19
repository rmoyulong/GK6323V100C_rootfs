setenv ipaddr 192.168.1.200
setenv netmask 255.255.255.0
setenv serverip 192.168.1.50
ping 192.168.1.50
tftpboot 0x04000000 boot.img
mmc write 0 0x04000000 0x38000 0x6B09
reset
