#!/bin/bash
. `dirname $0`/prompt.inc || exit 1

CHKNAME=dl380.shopsmart.au.nu
[ "`hostname`" = "$CHKNAME" ] || abort "`hostname` not [$CHKNAME]"
. `dirname $0`/ceph-install.conf || abort "ceph-install.conf err"

CMD="$1"
# [ -z "$CMD" ] && CMD="create"
[ -z "$CMD" ] && abort "needs CMD[create,delete,snapshot,rollback]"
	NAME="$2"
### CREATE ###
if [ "$CMD" = "create" ]; then
	prompt "create [$CEPH_ALL]"
	for H in $CEPH_ADMIN $CEPH_MON $CEPH_MGR $CEPH_CLI $CEPH_MDS; do
		[ -z "$NAME" ] || [ "$H" = "$NAME" ] || continue
		
		set -x
virt-install --connect qemu:///system --vnc --vnclisten=0.0.0.0 \
--network=bridge=br0 \
--location=nfs:cirrus:/data/centos7/  \
--wait 0 \
--extra-args "inst.ks=http://kickstart.shopsmart.au.nu/cgi-bin/ks.cgi?TEMPLATE=ceph&HOSTNAME=$H" \
-r 16384 --vcpus=8 \
--disk size=30,format=qcow2 \
--name $H
		set +x
#--network=bridge=br5 \
	done
	for H in $CEPH_OSD; do
		[ -z "$NAME" ] || [ "$H" = "$NAME" ] || continue
		set -x
virt-install --connect qemu:///system --vnc --vnclisten=0.0.0.0 \
--network=bridge=br0 \
--location=nfs:cirrus:/data/centos7/  \
--wait 0 \
--extra-args "inst.ks=http://kickstart.shopsmart.au.nu/cgi-bin/ks.cgi?TEMPLATE=ceph&HOSTNAME=$H" \
-r 16384 --vcpus=8 \
--disk size=30,format=qcow2 \
--disk size=30,format=qcow2 \
--name $H

		set +x
#--network=bridge=br5 \
	done
fi
	
### DELETE ###
if [ "$CMD" = "delete" ]; then
	prompt "delete [$CEPH_ALL]"
	for H in $CEPH_ALL; do
		set -x
		virsh destroy $H
		virsh undefine --remove-all-storage $H
		set +x
	done
fi

### list ###
if [ "$CMD" = "list" ]; then
	print "list [$CEPH_ALL]"
	for H in $CEPH_ALL; do
		set -x
		virsh snapshot-list --tree  --domain ${H}
		set +x
	done
fi
	

	
SNAP="$2"
[ -z "$SNAP" ] && SNAP=os-installed

### SNAPSHOT ###
if [ "$CMD" = "snapshot" ]; then
	prompt "snapshot [$SNAP]@[$CEPH_ALL]"
	for H in $CEPH_ALL; do
		set -x
		virsh snapshot-create-as --name ${SNAP} --domain ${H}
		set +x
	done
fi
	

### SNAPDEL ###
if [ "$CMD" = "snapdel" ]; then
	prompt "snapdel [$SNAP]@[$CEPH_ALL]"
	for H in $CEPH_ALL; do
		set -x
		virsh snapshot-delete --snapshotname  ${SNAP} --domain ${H}
		set +x
	done
fi
	

### ROLLBACK ###
if [ "$CMD" = "rollback" ]; then
	prompt "rollback [$SNAP]@[$CEPH_ALL]"
	for H in $CEPH_ALL; do
		set -x
		virsh snapshot-revert --snapshotname ${SNAP} --domain ${H}
		virsh start --domain ${H}
		set +x
	done
fi
	

### STOP ###
if [ "$CMD" = "stop" ]; then
	prompt "stop [$CEPH_ALL]"
	for H in $CEPH_ALL; do
		set -x
		virsh destroy $H
		set +x
	done
fi
	
### start ###
if [ "$CMD" = "start" ]; then
	prompt "start [$CEPH_ALL]"
	for H in $CEPH_ALL; do
		set -x
		virsh start $H
		set +x
	done
fi
	


