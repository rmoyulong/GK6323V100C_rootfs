cat /proc/partitions
for p in /sys/block/mmcblk0/mmcblk0p*; do
  echo "$(basename $p) start=$(cat $p/start) size=$(cat $p/size)"
done
findmnt / ; cat /proc/cmdline
