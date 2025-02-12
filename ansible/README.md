# Ansible Playbook for Proxmox VM Management

This Ansible playbook automates the creation, deletion, and configuration of 
virtual machines (VMs) on a Proxmox server.

## Prerequisites

- Ansible installed on the local machine
- Ansible community.general.proxmox_kvm module
- Access to a Proxmox server with API access enabled
- Python `proxmoxer` library installed (`pip install proxmoxer`)

## Setup

1. Clone this repository:
    ```sh
    git clone https://github.com/TheTaqiTahmid/proxmox_ansible_automation
    ```

2. Update the `inventory` file with your Proxmox server details:
    ```yaml
    all:
      hosts:
        proxmox:
          ansible_host: your_proxmox_ip
          ansible_user: your_proxmox_user
          ansible_password: your_proxmox_password
    ```
    In the current example implementation in `inventories/hosts.yaml`, there are
    multiple groups depending on the types of hosts.

3. Add group-related variables to the group file under the `group_vars` directory
   and individual host-related variables to the files under the `host_vars` 
  directory. Ansible will automatically pick up these variables.

## Playbooks

### Create VM

To create the VMs, run the following command:
```sh
ansible-playbook playbooks/create-vms.yaml
```
The playbook can be run against specific Proxmox instance using:
```sh
ansible-playbook playbooks/create-vms.yaml --limit proxmox1
```

### Delete VM

To delete existing VMs, run the following command:
```sh
ansible-playbook playbooks/destroy-vms.yaml
```

Similarly the destory playbook can be run against specific Proxmox instance using:
```sh
ansible-playbook playbooks/destroy-vms.yaml --limit proxmox1
```

### Configure VM

To configure an existing VM, run the following command:
```sh
ansible-playbook playbooks/configure-vms.yaml
```

The configuration can be limited to individual VMs using limits:
```sh
ansible-playbook playbooks/configure-vms.yaml --limit vm6
```

## Variables

The playbooks use the following variables, which can be customized in the 
`group_vars/proxmox.yml` file:

- `vm_id`: The ID of the VM
- `vm_name`: The name of the VM
- `vm_memory`: The amount of memory for the VM
- `vm_cores`: The number of CPU cores for the VM
- `vm_disk_size`: The size of the VM disk

## Author

- Taqi Tahmid (mdtaqitahmid@gmail.com)
