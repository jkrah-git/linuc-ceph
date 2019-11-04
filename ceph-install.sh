#!/bin/bash
. `dirname $0`/prompt.inc || exit 1

[ "`whoami`" = "cephuser" ] || abort "must be run as cephuser"

prompt "Install ceph ?"

     [ -f ~/.ssh/id_rsa ] || ssh-keygen -N "" -f ~/.ssh/id_rsa

###
setup_host()
{
	H="$1"
	[ -z "$H" ] && retur
	echo "========== $H =========="
	IP="`host $H | awk '/ has address / { print $NF }'`"
	grep $H /etc/hosts || echo "$IP    $H" | sudo tee -a /etc/hosts

	[ -f ~/.ssh/config ]  || touch ~/.ssh/config
	grep "^Host $H" ~/.ssh/config || printf "Host $H\n\tHostname $H\n\tUser cephuser\n\n" >> ~/.ssh/config
	chmod 644 ~/.ssh/config

	[ -f ~/.ssh/known_hosts ] || touch ~/.ssh/known_hosts
	grep "^$H" ~/.ssh/known_hosts || ssh-keyscan $H >> ~/.ssh/known_hosts

}

for H in ceph-admin ceph-mon1 ceph-osd1 ceph-osd2 ceph-osd3; do
setup_host $H
done
