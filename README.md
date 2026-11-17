GK6323V100C

boot.img: u-boot legacy uImage, GK6323V100C Linux 6.18.46 ARM64 \037 \003\325, Linux/ARM 64-bit, OS Kernel Image (Not compressed), 14028808 bytes, Sun Nov 15 13:25:05 2026, Load Address: 0X2000000, Entry Point: 0X2000000, Header CRC: 0X63DD1679, Data CRC: 0XA6BE046B


恢复安卓ttl刷机：
万能包-国科微GK6323-安卓9-TTL-烧录固件包_兼容三网遥控及有无wifi主板.zip

debian刷机：
https://bbs.histb.com/d/4814-zhao-ge-yi-dong-yun-dian-nao-z71aec-ma01-guo-ke-gk6323v100chu-li-qi-debian-ttlshao-lu-bao
【温馨提示（刷机前必看）】

强烈建议您在刷机前，先使用 HiTool 备份好自己机器的原厂全分区，留存备份后
即可随时刷回原厂安卓系统。
海思国科平台 Hitool 备份全分区教程：https://www.right.com.cn/forum/thread-8497713-1-1.html
如遇到刷完 Debian 后无法开机的情况，请提供完整的 TTL 串口启动日志 与该设备的
原厂全分区备份 协助定位。
一、刷机前文件准备（必读）

本目录已为您配置好本机型的引导镜像、内核镜像以及 [分区表_Debian.xml]。
【统一手动放置 rootfs.img】：
各机型通用同一份 Debian rootfs.img（由您统一存放并按需复制使用）。
通用 rootfs.img 百度网盘下载地址：链接: https://pan.baidu.com/s/1gqkOPglQtIkPF8Me0jMxbA?pwd=umt5 提取码: umt5
下载并开始刷机前，请务必将 rootfs.img 手动放置到本目录下（与 [分区表_Debian.xml]
同一级目录），确保文件名为 rootfs.img。
操作前请先断开机顶盒电源，接好 TTL 串口线与网线（与电脑同局域网或网线直连）。
二、HiTool 烧录步骤（在原厂固件基础上直接刷入 Debian）

打开 HiTool，芯片选择 Hi3798MV310，点击界面上的 【HiBurn】。

传输方式选择 【网口】（配合连接好的串口号 COMx），页签切到 【烧写 eMMC】。

点击 【浏览分区表】，导入本目录下的 分区表_Debian.xml。

检查勾选（脚本已预设好，无需修改）：

默认仅勾选 5 个核心文件：bootargs.img、bootargsbak.img、dtbo.img、
boot.img、rootfs.img。
其余原厂底层分区及出厂凭证（deviceinfo、securestore）均不勾选，安全快速。
点击 【烧写】 按钮后，再立即给机顶盒插电开机，HiTool 将自动握手并开始刷机。

提示烧写全部成功后，断开串口/关闭 HiTool，给盒子断电重启等待约 2030 秒。

备选救砖：若机顶盒原先底层分区已被破坏导致上述方法无法开机，确保本目录底包
齐全后可改用 [分区表_全盘救砖.xml] 重刷（已自动保护 deviceinfo、securestore 不被覆盖）。

三、默认用户名、密码与登录方法

默认用户名：root
默认密码 ：123456
SSH 远程登录（端口 22）：
插上网线正常开机后，路由器会为盒子分配 IP（串口也会打印 IP；路由器设备名通常为
Hi3798MV320-NAS），使用终端或 Xshell/FinalShell 连接：
ssh root@<盒子IP>
TTL 串口登录：
串口软件设置波特率 115200，通电启动完毕后支持直接免密进入 root 命令行。
四、开机后常用操作

建议首次登录后修改默认密码：
passwd
首次开机会自动扩展分区至整颗 eMMC；如 df -h / 仍显示约 1GB，手动执行一次：
resize2fs /dev/mmcblk0p18
通过网盘分享的文件：Z71A
链接: https://pan.baidu.com/s/1EyV6kkMBUyek6V5XP1Pk8w?pwd=cqpn 提取码: cqpn