# Terraform Configuration

> This project uses OpenTofu instead of Terraform. OpenTofu is a fork of
> Terraform that is compatible with Terraform configurations and provides
> similar functionality.

This directory contains Terraform configurations for managing
infrastructure resources. It includes configurations for Proxmox.

Currently, only the Proxmox virtual machines are managed using Terraform.
Kubernetes clusters are still created with Ansible, and Kubernetes resources are
managed using Helm charts and kubectl. Previously, Proxmox was also managed with
Ansible, but it has been moved to Terraform for improved consistency and state
management. The goal is to eventually manage all infrastructure—including
Kubernetes clusters—using Terraform.

The terraform state files are stored in a remote backend, which allows for
collaboration and state management across different environments. The backend
configuration is defined in the `backend.tf` file. The backend is set up to use
minio as the storage backend.

## Proxmox

Ref: https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_hosts

The Proxmox configuration is located in the `proxmox` directory.
It uses the Proxmox provider to manage virtual machines and other resources.

The workflow for managing Proxmox resources is as follows:

```bash
cd proxmox
source .env
tofu init
tofu plan
tofu apply
```

## Kubernetes and Helm
