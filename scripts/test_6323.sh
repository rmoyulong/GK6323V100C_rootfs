lsusb
aplay -l
df -h

dmesg | grep "gk6323v100c-crg"        # 应见 clk[...] 与 rst released[...] 两行
ip link show eth0                     # 应存在


ethtool eth0 | grep -iE "speed|duplex|link detected"   # 期望 Speed:100Mb/s、Full
cat /sys/class/net/eth0/carrier                        # 插网线应为 1
cat /sys/bus/mdio_bus/devices/*/phy_id                 # 期望 0x2066xxxx，不再是 0
dmesg | grep -iE "femac|fephy|mdio"                    # 不应再 error

