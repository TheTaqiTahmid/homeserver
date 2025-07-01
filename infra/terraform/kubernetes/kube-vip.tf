# No new namespace is required since it is being deployed in kube-system namespace.
resource "helm_release" "kube_vip" {
  name       = "kube-vip"
  repository = "https://kube-vip.github.io/helm-charts"
  chart      = "kube-vip"
  version    = "0.6.6"
  atomic     = true

  namespace = "kube-system"

  values = [
      templatefile("${var.kubernetes_project_path}/kube-vip/values.yaml", {
        VIP_ADDRESS = var.vip_address
      })
  ]
}