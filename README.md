# 🏠 Homeserver Setup Guide: Kubernetes on Proxmox

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

```
© 2023 Taqi Tahmid
```

> Build your own modern homelab with Kubernetes on Proxmox! This guide walks
> you through setting up a complete home server infrastructure with essential
> self-hosted services.

## 🌟 Highlights

- Fully automated setup using Ansible
- Production-grade Kubernetes (K3s) cluster
- High-availability Proxmox configuration
- Popular self-hosted applications ready to deploy

## 📁 Repository Structure

- `ansible/` - Automated provisioning with Ansible playbooks. [Ansible Guide](ansible/README.md)
- `kubernetes/` - K8s manifests and Helm charts. [Kubernetes Guide](kubernetes/README.md)
- `docker/` - Legacy docker-compose files (Kubernetes preferred). [Docker Guide](docker/README.md)

## 🚀 Running Services

- ✨ AdGuard Home - Network-wide ad blocking
- 🐳 Private Docker Registry
- 🎬 Jellyfin Media Server
- 🌐 Portfolio Website
- 🗄️ PostgreSQL Database
- 📦 Pocketbase Backend
- 🍵 Gitea Git Server

### 📋 Coming Soon
- Nextcloud
- Monitoring Stack

## 💻 Hardware Setup

- 2x Mini PCs with Intel N1000 CPUs
- 16GB RAM each
- 500GB SSDs
- 1Gbps networking
- Proxmox Cluster Configuration

## 🛠️ Installation Steps

### 1. Setting up Proxmox Infrastructure

#### Proxmox Base Installation
- Boot mini PCs from Proxmox USB drive
- Install on SSD and configure networking
- Set up cluster configuration
> 📚 Reference: [Official Proxmox Installation Guide](https://pve.proxmox.com/wiki/Installation)

#### 3. Cloud Image Implementation

Cloud images provide:
- 🚀 Pre-configured, optimized disk images
- 📦 Minimal software footprint
- ⚡ Quick VM deployment
- 🔧 Cloud-init support for easy customization

These lightweight images are perfect for rapid virtual machine deployment in
your homelab environment.

#### Proxmox VM Disk Management

**Expanding VM Disk Size:**
1. Access Proxmox web interface
2. Select target VM
3. Navigate to Hardware tab
4. Choose disk to resize
5. Click Resize and enter new size (e.g., 50G)

**Post-resize VM Configuration:**
```bash
# Access VM and configure partitions
sudo fdisk /dev/sda
# Key commands:
# p - print partition table
# d - delete partition
# n - create new partition
# w - write changes
sudo mkfs.ext4 /dev/sdaX
```

#### Physical Disk Passthrough
Pass physical disks (e.g., NVME storage) to VMs:
```bash
# List disk IDs
lsblk |awk 'NR==1{print $0" DEVICE-ID(S)"}NR>1{dev=$1;printf $0" ";system("find /dev/disk/by-id -lname \"*"dev"\" -printf \" %p\"");print "";}'|grep -v -E 'part|lvm'

# Add disk to VM (example for VM ID 103)
qm set 103 -scsi2 /dev/disk/by-id/usb-WD_BLACK_SN770_1TB_012938055C4B-0:0

# Verify configuration
grep 5C4B /etc/pve/qemu-server/103.conf
```
> 📚 Reference: [Proxmox Disk Passthrough Guide](https://pve.proxmox.com/wiki/Passthrough_Physical_Disk_to_Virtual_Machine_(VM))

### 2. Kubernetes Cluster Setup

#### K3s Cluster Configuration
Setting up a 4-node cluster (2 master + 2 worker):

**Master Node 1:**
```bash
curl -sfL https://get.k3s.io | sh -s - server --cluster-init --disable servicelb
```

**Master Node 2:**
```bash
export TOKEN=<token>
export MASTER1_IP=<ip>
curl -sfL https://get.k3s.io | sh -s - server --server https://${MASTER1_IP}:6443 --token ${TOKEN} --disable servicelb
```

**Worker Nodes:**
```bash
export TOKEN=<token>
export MASTER1_IP=<ip>
curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER1_IP}:6443 K3S_TOKEN=${TOKEN} sh -
```

#### MetalLB Load Balancer Setup
```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

# Verify installation
kubectl get pods -n metallb-system

# Apply configuration
kubectl apply -f /home/taqi/homeserver/k3s-infra/metallb/metallbConfig.yaml
```

**Quick Test:**
```bash
# Deploy test nginx
kubectl create namespace nginx
kubectl create deployment nginx --image=nginx -n nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer -n nginx

# Cleanup after testing
kubectl delete namespace nginx
```

## 🤝 Contributing

Contributions welcome! Feel free to open issues or submit PRs.

## 📝 License

MIT License - feel free to use this as a template for your own homelab!