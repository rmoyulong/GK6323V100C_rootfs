# 1. 把原厂bootargs替换成我们需要的Linux启动参数，用2G内存模式
setenv bootargs 'earlycon=pl011,mmio32,0xf8b00000,115200n8 console=ttyAMA0,115200n8 console=tty0 clk_ignore_unused net.ifnames=0 root=/dev/mmcblk0p18 rootfstype=ext4 rootwait rw panic=-1 fsck.mode=force fsck.repair=yes blkdevparts=mmcblk0:1M(fastboot),512K(bootargs),512K(bootargsbak),20M(recovery),2M(deviceinfo),8M(securestore),2M(atf),8M(baseparam),8M(pqparam),2M(dtbo),10M(logo),10M(logobak),20M(fastplay),20M(recoverybak),60M(boot),20M(misc),20M(trustedcore),-(rootfs)'

# 2. 保存环境变量到eMMC，以后每次启动都用这个参数，不用再改
saveenv

# 3. 启动系统
reset
-------------------------------------------------------------
启动一次让系统自动做全量文件系统检查，确认没有ext4报错；
进系统后验证：
bash
dmesg | grep -i ext4    # 没有group XX inconsistent、没有"mounting fs with errors"
free -h                 # 还是1.9Gi
systemctl --failed      # 没有失败服务（wait-online那个不影响可以忽略）

验证完把U-Boot里临时加的fsck.mode=force fsck.repair=yes删掉，saveenv保存


-----------------------
测试 
apt insall -y memtester

 stdbuf -oL memtester 384 5 | tee /root/ddr-diag/memtester.lomemteste.log
 ---------------------
 stdbuf -oL memtester 1536 1| tee /root/ddr-diag/memtester.lomemteste.log
 
 刷完别直接扫库，先按这个顺序测
‌先测高位内存‌：memtester 1536 1，专门压1GB以上的高地址段，这部分之前384M的测试从来没碰到过；
全过 → 高位内存没问题，下一步测eMMC写入
崩 → 高1GB内存映射有问题，回头查U-Boot DDR初始化
‌再测eMMC写入‌：dd if=/dev/zero of=/root/t bs=1M count=2048 conv=fsync，单独压存储路径，排除eMMC驱动问题；
‌最后才扫库‌：两步都过了再开LMS扫5000首，此时如果还崩再接串口抓复位前日志。
刷完把启动后的dmesg和memtester 1536的结果发我就行。

Unknown command '[200~md' - try 'help'
fastboot#help
?         - alias for 'help'
OTP_getmsid- Get msid
OTP_getstbsn- Get stb sn
OTP_getvendorid- Get vendor id
OTP_setmsid- Set MSID
OTP_setstbsn- Set stb sn
base      - print or set address offset
bootm     - boot application image from memory
bootp     - boot image via network using BOOTP/TFTP protocol
cmp       - memory compare
cp        - memory copy
crc32     - checksum calculation
ddr       - ddr training function
env       - environment handling commands
fatinfo   - print information about filesystem
fatload   - load binary file from a dos filesystem
fatls     - list files in a directory (default /)
fatmkdir  - create a directory
fatrm     - delete a file
fatsize   - determine a file's size
fatwrite  - write file into a dos filesystem
getinfo   - print hardware information
gzwrite   - unzip and write memory to block device
help      - print command description/usage
loadb     - load binary file over serial line (kermit mode)
loadx     - load binary file over serial line (xmodem mode)
loady     - load binary file over serial line (ymodem mode)
loop      - infinite loop on address range
md        - memory display
mii       - MII utility commands
mm        - memory modify (auto-incrementing address)
mmc       - MMC sub system
mmcinfo   - display MMC info
mw        - memory write (fill)
nm        - memory modify (constant address)
otp_burntonormalchipset- Burn to normal chipset, please be careful !!!
otp_burntosecurechipset- Burn to secure chipset, please be careful !!!
otp_getbootkeyslotlock- Get root key slot lock flag
otp_getbootmode- Get Boot mode
otp_getcas0keyslotlock- Get root key slot lock flag
otp_getcas1keyslotlock- Get root key slot lock flag
otp_getcas2keyslotlock- Get root key slot lock flag
otp_getcas3keyslotlock- Get root key slot lock flag
otp_getcas4keyslotlock- Get root key slot lock flag
otp_getcas5keyslotlock- Get root key slot lock flag
otp_getcas6keyslotlock- Get root key slot lock flag
otp_getcas7keyslotlock- Get root key slot lock flag
otp_getcustomerkey- otp_getcustomerkey 
otp_getddrwakeupstatus- Get DDR wakeup status
otp_getrsashalock- Get RSA HASH lock flag
otp_getsecurewordlock- Get ID word lock flag
otp_getsmshalock- Get sm HASH lock flag
otp_getstbmkeyslotlock- Get root key slot lock flag
otp_getstbprivdata- otp_getstbprivdata 
otp_gettrustzonestat- Get TEE status
otp_setbootkeyslot- Set boot root key slot
otp_setbootmode- Set Boot mode
otp_setcas0keyslot- Set cas0 root key slot
otp_setcas1keyslot- Set cas1 root key slot
otp_setcas2keyslot- Set cas2 root key slot
otp_setcas3keyslot- Set cas3 root key slot
otp_setcas4keyslot- Set cas4 root key slot
otp_setcas5keyslot- Set cas5 root key slot
otp_setcas6keyslot- Set cas6 root key slot
otp_setcas7keyslot- Set cas7 root key slot
otp_setrsasha- Set RSA HASH
otp_setsmsha- Set SM HASH
otp_setstbmkeyslot- Set stbm root key slot
otp_setstbprivdata- StbPrivData 
otp_settrustzone- Set TEE enable
otpreadall- read otp ,for example otpreadall 
otpwrite  - write otp ,for example otpwrite adddress value 
ping      - send ICMP ECHO_REQUEST to network host
printenv  - print environment variables
reset     - Perform RESET of the CPU
saveenv   - save environment variables to persistent storage
setenv    - set environment variables
switchns  - switchns
tftp      - tftp	- download or upload image via network using TFTP protocol
tftpboot  - boot image via network using TFTP protocol
tftpput   - TFTP put command, for uploading files to a server
unzip     - unzip a memory region
usb       - USB sub-system
usbboot   - boot from USB device
version   - print monitor, compiler and linker version



setenv bootargs 'mem=1024M mmz=ddr,0,0,52M earlycon=pl011,mmio32,0xf8b00000,115200n8 console=ttyAMA0,115200n8 console=tty0 clk_ignore_unused net.ifnames=0 root=/dev/mmcblk0p18 rootfstype=ext4 rootwait rw panic=-1 blkdevparts=mmcblk0:1M(fastboot),512K(bootargs),512K(bootargsbak),20M(recovery),2M(deviceinfo),8M(securestore),2M(atf),8M(baseparam),8M(pqparam),2M(dtbo),10M(logo),10M(logobak),20M(fastplay),20M(recoverybak),60M(boot),20M(misc),20M(trustedcore),-(rootfs)'
saveenv