# Deploy kubernetes cluster in openstack using kubeadm

The bash script `start.sh` creates and deletes the infrastructure in an
openstack cloud.

You need to modify some parameters in the start.sh script to fit your
requirements (it only works with Ubuntu Xenial):

```
source $HOME/admin.rc
OS_FLAVOR_NAME=m2.medium 
OS_FLAVOR_STORAGE=storage1 # Flavor with ephemeral storage to add ceph
OS_IMAGE_ID=1ba7a454-a69d-4057-a3fd-e1aa3a00b169 # Ubuntu Xenial May 18th 2017
NUM_WORKERS=4
```

The script has several options: {create|create_k8s|create_storage|delete}"

* create: Create VMs for a k8s cluster and 1 nodes for Ceph storage
* create_k8s: Create only the VMs for the k8s cluster
* create_storage: Create only the storage node
* delete: Delete all the VMs created

The script creates an inventory file that is used by ansible with the public ip addresses of the hosts.

Once the VMs are deployed you need to provision them with ansible:

`ansible-playbook -i inventory playbook.yaml`

*WARNING* The k8s cluster has disabled the security to access the dashboard and everybody can access it in the following URL.

`https://MASTER_PUBLIC_IP:6443/ui`

There is an example deployment called sock-shop that you can access checking the public port used by the NodePort service in the sock-shop namespace (it can take a few minutes to become available)

`kubectl -n sock-shop get svc front-end`

`http://<master_ip>:<port>`

Once you finish you can delete everything:

`start.sh delete`

References:

https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/


