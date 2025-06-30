terraform {
    required_providers {
        kubernetes = {
        source  = "hashicorp/kubernetes"
        version = "2.37.1"
        }
        helm = {
            source  = "hashicorp/helm"
            version = "3.0.2"
        }
    }
}

provider "kubernetes" {
    config_path = "~/.kube/config"
}

provider "helm" {
    kubernetes {
        config_path = "~/.kube/config"
    }
}