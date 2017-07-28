#!/usr/bin/bash

# Configuration variables, modify to fit your environment
source $HOME/admin.rc
OS_FLAVOR_NAME=m2.medium # Storage 40GB and RAM 4GB
OS_FLAVOR_STORAGE=storage1 # 1gb Ram and 40GB Hdisk for root disk and ephemeral
OS_IMAGE_ID=1ba7a454-a69d-4057-a3fd-e1aa3a00b169 # Ubuntu Xenial May 18th 2017
NUM_WORKERS=4

common()
{
    # Check if we have the infra created in openstack
    if  ! neutron net-list | grep k8s
    then
      neutron net-create k8s-network
      neutron subnet-create --name k8s-subnet --dns-nameserver 8.8.8.8 --enable-dhcp --allocation_pool "start=192.168.0.100,end=192.168.0.200" k8s-network 192.168.0.0/24
      neutron router-create k8s-router
      neutron router-gateway-set k8s-router external
      neutron router-interface-add k8s-router subnet=k8s-subnet
      nova keypair-add --pub-key $HOME/.ssh/id_rsa.pub k8s-pub-key
    fi

    EXT_NET=$(neutron net-list | grep external | awk '{print $2;}')
    PRIV_NET=$(neutron net-list | grep k8s | awk '{print $2;}')
}

create_k8s()
{
    # Permit api keys
    nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
    nova secgroup-add-rule default tcp 3389 3389 0.0.0.0/0
    nova secgroup-add-rule default tcp 6443 6443 0.0.0.0/0
    nova secgroup-add-rule default tcp 8080 8080 0.0.0.0/0
    # Permit services ports
    nova secgroup-add-rule default tcp 30000 60000 0.0.0.0/0

    # Boot some instances
    NOVA_BOOT_ARGS="--key-name k8s-pub-key --image $OS_IMAGE_ID --flavor $OS_FLAVOR_NAME --nic net-id=$PRIV_NET"

    echo "[master]" > inventory
    nova boot ${NOVA_BOOT_ARGS} master1
    FIP=$(nova floating-ip-create $EXT_NET | grep external | awk '{print $4;}')
    nova floating-ip-associate master1 $FIP
    echo "master ansible_host=$FIP" >> inventory

    echo "[workers]" >> inventory
    for i in $(seq 1 $NUM_WORKERS)
    do
      nova boot ${NOVA_BOOT_ARGS} worker$i
      # Assign floatin ips
      FIP=$(nova floating-ip-create $EXT_NET | grep external | awk '{print $4;}')
      nova floating-ip-associate worker$i $FIP
      echo "worker$i ansible_host=$FIP" >> inventory
    done

    echo "All VMs created, run ansible-playbook -i inventory playbook.yaml to provision k8s"

}

create_storage()
{
    # Create the storage VM
    echo "[storage]" >> inventory
    nova boot --key-name k8s-pub-key --image $OS_IMAGE_ID --flavor $OS_FLAVOR_STORAGE --nic net-id=$PRIV_NET --user-data=ceph-single-node.sh --ephemeral size=40 ceph1
    FIP=$(nova floating-ip-create $EXT_NET | grep external | awk '{print $4;}')
    nova floating-ip-associate ceph1 $FIP
    echo "ceph1 ansible_host=$FIP" >> inventory
}

delete ()
{
    # delete all
    for i in $(nova list | grep k8s | awk '{ print $2 }')
    do
        nova delete $i
    done

    for i in $(neutron floatingip-list -f csv | grep \"\" | cut -f1 -d, | cut -f2 -d\") 
    do
        neutron floatingip-delete $i
    done
    rm inventory
}


case "$1" in
    create)
        common
        create_k8s
	create_storage
        ;;
    create_k8s)
        common
        create_k8s
        ;;
    create_storage)
        common
        create_storage
        ;;
    delete)
        delete
        ;;
    *)
        echo "Usage: $0 {create|create_k8s|create_storage|delete}"
        ;;
esac
