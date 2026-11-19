echo "将flash-boot.sh放到/root/scripts目录下"
echo "将up_core_from_tmp.sh放到/root目录下"
echo "sudo sh up_core_from_tmp.sh"

sudo bash /root/scripts/flash-boot.sh \
     -i /tmp/boot.img \
     -m /tmp/modules.tar.gz \
     -d /tmp/gk6323v100c-chaoge-z71a.dtb
sync	 
sudo reboot
