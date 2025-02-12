# Homeserver Setup

```
© 2023 Taqi Tahmid
```

This is the top level directory for the homeserver setup. It contains the
following directories:

1. `ansible`: Contains the ansible playbooks and roles for setting up the
homeserver. Proxmox is used as the hypervisor, so the playbooks are written with
that in mind. The Kubernetes cluster is set up using K3s. This has not been
automated yet and is a manual process.

2. `docker`: Contains the docker-compose files for setting up the different
services. Right now Kubernetes is preferred over docker-compose, so this
directory is not actively maintained.

3. `kubernetes`: Contains the kubernetes manifests and helm charts for setting
up the different services.


# Services

The following services are set up on the homeserver:
1. AdGuard Home
2. Private Docker Registry
3. Jellyfin
4. My Portfolio Website
5. Postgres Database
6. Pocketbase Backend

In future the following services are planned to be set up:
1. Nextcloud
2. Gitea
3. Monitoring Stack


# Homeserver Setup

I have two mini PCs with Intel N1000 CPUs and 16GB of RAM each and 500GB SSDs.
Both of them are running Proxmox and are connected to a 1Gbps network. The
Proxmox is set up in a cluster configuration.

There are four VMs dedicated for the Kubernetes cluster. The VMs are running
Ubuntu 22.04 and have 4GB of RAM and 2 CPUs each. The VMs are connected to a
bridge network so that they can communicate with each other. Two VMs are
confiugred as dual control plane and worker nodes and two VMs are configured as
worker nodes. The Kubernetes cluster is set up using K3s.

## Proxmox Installation

The Proxmox installation is done on the mini PCs. The installation is done by
booting from a USB drive with the Proxmox ISO. The installation is done on the
SSD and the network is configured during the installation. The Proxmox is
configured in a cluster configuration.

Ref: [proxmox-installation](https://pve.proxmox.com/wiki/Installation)

## Promox VM increase disk size

Access the Proxmox Web Interface:

1. Log in to the Proxmox web interface.
   Select the VM:
2. In the left sidebar, click on the VM to resize.
   Resize the Disk:
3. Go to the Hardware tab.
4. Select the disk to resize (e.g., scsi0, ide0, etc.).
5. Click on the Resize button in the toolbar.
6. Enter 50G (or 50000 for 50GB) in the size field.

After that login to the VM and create a new partition or add to existing one
```
sudo fdisk /dev/sda
Press p to print the partition table.
Press d to delete the existing partition (note: ensure data is safe).
Press n to create a new partition and follow the prompts. Make sure to use the
same starting sector as the previous partition to avoid data loss. Press w to
write changes and exit.
sudo mkfs.ext4 /dev/sdaX
```

## Proxmox Passthrough Physical Disk to VM

Ref: [proxmox-pve](https://pve.proxmox.com/wiki/Passthrough_Physical_Disk_to_Virtual_Machine_(VM))
It is possible to pass through a physical disk attached to the hardware to
the VM. This implementation passes through a NVME storage to the
dockerhost VM.

```bash
# List the disk by-id with lsblk
lsblk |awk 'NR==1{print $0" DEVICE-ID(S)"}NR>1{dev=$1;printf $0" \
  ";system("find /dev/disk/by-id -lname \"*"dev"\" -printf \" %p\"");\
  print "";}'|grep -v -E 'part|lvm'

# Hot plug or add the physical device as a new SCSI disk
qm set 103  -scsi2 /dev/disk/by-id/usb-WD_BLACK_SN770_1TB_012938055C4B-0:0

# Check with the following command
grep 5C4B  /etc/pve/qemu-server/103.conf

# After that reboot the VM and verify with lsblk command
lsblk
```

## Setup Master and worker Nodes for K3s

The cluster configuration consists of 4 VMs configured as 2 master and 2 worker k3s nodes.
The master nodes also function as worker nodes.

```bash
# On the first master run the following command
curl -sfL https://get.k3s.io | sh -s - server --cluster-init --disable servicelb

# This will generate a token under /var/lib/rancher/k3s/server/node-token
# Which will be required to for adding nodes to the cluster

# On  the second master run the following command
export TOKEN=<token>
export MASTER1_IP=<ip>
curl -sfL https://get.k3s.io | \
    sh -s - server --server https://${MASTER1_IP}:6443 \
    --token ${TOKEN} --disable servicelb

# Similarly on the worker nodes run the following command
export TOKEN=<token>
export MASTER1_IP=<ip>
curl -sfL https://get.k3s.io | \
  K3S_URL=https://${MASTER1_IP}:6443 K3S_TOKEN=${TOKEN} sh -
```

## Configure Metallb load balancer for k3s

The metallb loadbalancer is used for services instead of k3s default
servicelb as it offers advanced features and supports IP address pools for load
balancer configuration.

```bash
# On any of the master nodes run the following command
kubectl apply -f \
  https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

# Ensure that metallb is installed with the following command
kubectl get pods -n metallb-system

# On the host machine apply the metallb cofigmap under metallb directory
kubectl apply -f /home/taqi/homeserver/k3s-infra/metallb/metallbConfig.yaml

# Test that the loadbalancer is working with nginx deployment
kubectl create namespace nginx
kubectl create deployment nginx --image=nginx -n nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer -n nginx

# If nginx service gets an external IP and it is accessible from browser then
the configuration is complete
kubectl delete namespace nginx
```

## Cloud Image for VMs

A cloud image is a pre-configured disk image that is optimized for use in cloud
environments. These images typically include a minimal set of software and
configurations that are necessary to run in a virtualized environment,
such as a cloud or a hypervisor like Proxmox. Cloud images are designed to be
lightweight and can be quickly deployed to create new virtual machines. They
often come with cloud-init support, which allows for easy customization and
initialization of instances at boot time.

The cloud iamges are used for setting up the VMs in Proxmox. No traditional
template is used for setting up the VMs. The cloud images are available for
download from the following link:
[Ubuntu 22.04](https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img)