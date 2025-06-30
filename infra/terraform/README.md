# Terraform Configuration

> This project uses OpenTofu instead of Terraform. OpenTofu is a fork of
> Terraform that is compatible with Terraform configurations and provides
> similar functionality.

This directory contains Terraform configurations for managing
infrastructure resources. It includes configurations for Proxmox.

The plan is to eventually migrate all infrastructure management to Terraform,
including Kubernetes clusters and other resources. Currently, the Proxmox
configuration is fully managed by Terraform, while Kubernetes resources are
managed using Helm charts and kubectl commands. Previously, the Proxmox
configuration was managed using Ansible, but it has been migrated to Terraform
for better consistency and state management.

The terraform state files are stored in a remote backend, which allows for
collaboration and state management across different environments. The backend
configuration is defined in the `backend.tf` file. The backend is set up to use
minio as the storage backend.

## Proxmox

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
