#!/bin/bash
. `dirname $0`/prompt.inc || exit 1

[ "`whoami`" = "cephuser" ] || abort "must be run as cephuser"

CMD="`basename $0`"
echo "CMD=[$CMD]"
###

setup_host()
{
	H="$1"
	[ -z "$H" ] && return
	print "========== $H =========="
	IP="`host $H | awk '/ has address / { print $NF }'`"
	set -x
	grep $H /etc/hosts > /dev/null || echo "$IP    $H" | sudo tee -a /etc/hosts

	[ -f ~/.ssh/config ]  || touch ~/.ssh/config
	grep "^Host $H" ~/.ssh/config > /dev/null || printf "Host $H\n\tHostname $H\n\tUser cephuser\n\n" >> ~/.ssh/config
	chmod 644 ~/.ssh/config

	[ -f ~/.ssh/known_hosts ] || touch ~/.ssh/known_hosts
	grep "^$H" ~/.ssh/known_hosts > /dev/null || ssh-keyscan $H >> ~/.ssh/known_hosts

	ssh-copy-id $H
	set +x
}

############## MAIN ###########
NAME="`hostname -s`"
## pre/common
[ -f ~/.ssh/id_rsa ] || ssh-keygen -N "" -f ~/.ssh/id_rsa
# breaks shit
#[ -f ~/.install.setup.noipv6 ] || /data/nfs/linux/disable-ipv6.sh > ~/.install.setup.noipv6


if [ "$CMD" = "ceph-install.sh" ]; then
	[ "$NAME" = "ceph-admin" ] || abort "must be run on ceph-admin"
	. `dirname $0`/ceph-install.conf || abort "config err"
	HOST_LIST="$*"
	[ -z "$HOST_LIST" ] && HOST_LIST=$CEPH_ALL

	prompt "Ceph Install ceph to [$HOST_LIST]?"
	
	print "setting up ssh keys.."
	for H in $HOST_LIST; do
		[ -f ~/.install.setup.hosts.$H ] && continue
		print "setup host [$H].."
		setup_host $H
		touch ~/.install.setup.hosts.$H
	done 

	for H in $HOST_LIST; do
		print "testing host [$H].."
		ssh $H "sudo hostname"
	done 

	prompt "run setup on all nodes"
	for H in $HOST_LIST; do
		print "setting up host [$H].."
		ssh $H "`dirname $0`/ceph-run.sh"
	done 

	## ---- main (install) done
	exit 0
fi

## else CMD=ceph-run.sh
TYPE="`echo $NAME | sed -e 's|^ceph-\([a-z]*\)[0-9]*|\1|g'`"
[ -z "$TYPE" ] && abort "Null ceph-typeX fron NAME[$NAME]"


print "Ceph ($TYPE) run on [$NAME].."
###


rpm -q epel-release  || sudo yum -y install epel-release
rpm -q yum-plugin-priorities || sudo yum -y install yum-plugin-priorities

## yum updates with new ceph repo
if [ ! -f /etc/yum.repos.d/ceph.repo ]; then
	sudo cp -p `dirname $0`/ceph.repo /etc/yum.repos.d/ceph.repo
	sudo yum clean all
	sudo yum -y update
fi

## admin
if [ "$TYPE" = "admin" ]; then
	
	if [ ! -f ~/.install.setup.fw ]; then
		print "fw rules.."
		sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
		sudo firewall-cmd --zone=public --add-port=2003/tcp --permanent
		sudo firewall-cmd --zone=public --add-port=4505-4506/tcp --permanent
		sudo firewall-cmd --reload
		touch ~/.install.setup.fw
	fi

	rpm -q ceph-deploy || (
		set -x
		sudo yum -y install python-setuptools ceph-deploy
		set +x
	)

fi

## mon
if [ "$TYPE" = "mon" ]; then
	if [ ! -f ~/.install.setup.fw ]; then
		print "fw rules.."
		sudo firewall-cmd --zone=public --add-port=6789/tcp --permanent
		# this is for mgr that might be on mon
		# sudo firewall-cmd --zone=public --add-port=7000/tcp --permanent 
		sudo firewall-cmd --reload
		touch ~/.install.setup.fw
	fi

fi


## mgr
if [ "$TYPE" = "mgr" ]; then
	if [ ! -f ~/.install.setup.fw ]; then
		print "fw rules.."
		sudo firewall-cmd --zone=public --add-port=7480/tcp --permanent
		sudo firewall-cmd --zone=public --add-port=7000/tcp --permanent 

		sudo firewall-cmd --reload
		touch ~/.install.setup.fw
	fi

fi

## osd
if [ "$TYPE" = "osd" ]; then
	if [ ! -f ~/.install.setup.fw ]; then
		print "fw rules.."
		sudo firewall-cmd --zone=public --add-port=6800-7300/tcp --permanent
		sudo firewall-cmd --reload
		touch ~/.install.setup.fw
	fi

	if [ ! -f ~/.install.setup.fdisk ]; then
		print "fdisk.."
		DISK=/dev/vdb
		set -x
		sudo parted -s $DISK mklabel gpt mkpart primary xfs 0% 100%
		sudo mkfs.xfs $DISK -f
		sudo blkid -o value -s TYPE $DISK
		set +x
		touch ~/.install.setup.fdisk
	fi
fi
