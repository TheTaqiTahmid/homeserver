resource "kubernetes_namespace" "portfolio" {
  metadata {
    name = "my-portfolio"
  }
}

resource "kubernetes_secret" "docker_secret" {
  metadata {
    name      = "docker-registry-credentials"
    namespace = "my-portfolio"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.docker_registry_host}" = {
          username = var.docker_username
          password = var.docker_password
          auth     = base64encode("${var.docker_username}:${var.docker_password}")
        }
      }
    })
  }

  depends_on = [kubernetes_namespace.portfolio]
}

locals {
  # Read and process the YAML file with placeholders
  manifest_content = templatefile("../../../kubernetes/my-portfolio/portfolioManifest.yaml", {
    PORTFOLIO_HOST  = var.portfolio_host
    DOCKER_REGISTRY_HOST = var.docker_registry_host
  })
  # Split into individual documents
  manifest_documents = split("---", replace(local.manifest_content, "/\\n\\s*\\n/", "---"))
}

resource "kubernetes_manifest" "portfolio_manifest" {
  for_each = { for i, doc in local.manifest_documents : i => doc if trimspace(doc) != "" }

  manifest = yamldecode(each.value)

  field_manager {
    force_conflicts = true
  }

  depends_on = [kubernetes_namespace.portfolio]
}