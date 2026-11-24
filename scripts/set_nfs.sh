apt install nfs-kernel-server -y
cat > /etc/exports <<EOF
# /etc/exports: the access control list for filesystems which may be exported
#               to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#
/mnt/music/music 192.168.1.0/24(ro,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
EOF

exportfs -ra && systemctl restart nfs-server


echo "NFS 服务端需放行端口：‌111（portmap）、2049（nfs）、20048（mountd）‌，TCP+UDP。你板子在 192.168.1.x 网段，刚好匹配 192.168.1.0/24"
echo "导出规则；跨网段时请确认中间是路由而非 NAT（NAT 下 NFSv3 mountd 反向回连易挂）。"
