terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}

provider "aws" {
  region = var.eks_cluster_region
  default_tags {
    tags = {
      Owner = var.owner
    }
  }
}

data "aws_eks_cluster" "karpenter_lab" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "karpenter_lab" {
  name = var.eks_cluster_name
}

provider "kubernetes" {
  host = data.aws_eks_cluster.karpenter_lab.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.karpenter_lab.certificate_authority[0].data)
  token = data.aws_eks_cluster_auth.karpenter_lab.token
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.karpenter_lab.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.karpenter_lab.certificate_authority[0].data)
    token = data.aws_eks_cluster_auth.karpenter_lab.token
  }
}

locals {
  deployment_date = formatdate("YYYY-MM-DD", timestamp())
  add_tolerations = true
  tolerations = local.add_tolerations ? [ "karpenter-lab" ] : []
}

# Lab 1
/*
resource "kubernetes_namespace_v1" "lab" {
  metadata {
    name = "karpenter-lab"
  }
}

resource "kubernetes_deployment_v1" "test_workload" {
  metadata {
    name = "karpenter-lab-workload"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }
  spec {
    template {
      metadata {
        labels = {
          name = "karpenter-lab"
          owner = var.owner
          deployed_by = "terraform"
        }
      }
      spec {
        dynamic "toleration" {
          for_each = local.tolerations
          content {
            key = toleration.value
            effect = "NoSchedule"
            operator = "Exists"
          }
        }
        container {
          name = "karpenter-lab-demo"
          image = "busybox"
          command = [ "/bin/sh" ]
          args = [ "-c", "sleep 7200" ]
          resources {
            requests = {
              cpu = "500m"
              memory = "3Gi"
            }
          }
        }
      }
    }
    selector {
      match_labels = {
        name = "karpenter-lab"
        owner = var.owner
        deployed_by = "terraform"
      }
    }
  }
}
*/

# Lab 2, first apply
/*
resource "aws_eks_addon" "identity-agent" {
  cluster_name = var.eks_cluster_name
  addon_name = "eks-pod-identity-agent"
  addon_version = "v1.0.0-eksbuild.1"
}

module "eks_karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.20.0"
  cluster_name = var.eks_cluster_name
  iam_policy_use_name_prefix = false
  iam_role_use_name_prefix = false
  node_iam_role_use_name_prefix = false
  enable_pod_identity = true
  create_pod_identity_association = true
  tags = {
    deployed_by = "terraform-aws-modules/eks/aws/modules//karpenter"
  }
}
*/

# Lab 2, second apply
/*
resource "helm_release" "karpenter_crd" {
  name = "karpenter-crd"
  chart = "oci://public.ecr.aws/karpenter/karpenter-crd"
  version = var.karpenter_version
  depends_on = [ module.eks_karpenter ]
}

resource "helm_release" "karpenter" {
  name = "karpenter"
  namespace = "kube-system"
  chart = "oci://public.ecr.aws/karpenter/karpenter"
  version = var.karpenter_version
  set {
    name = "replicas"
    value = 1
  }
  set {
    name = "settings.clusterName"
    value = var.eks_cluster_name
  }
  set {
    name = "settings.clusterEndpoint"
    value = data.aws_eks_cluster.karpenter_lab.endpoint
  }
  set {
    name = "settings.interruptionQueue"
    value = module.eks_karpenter.queue_name
  }
  set {
    name = "serviceAccount.name"
    value = module.eks_karpenter.service_account
  }
  set {
    name = "logLevel"
    value = "debug"
  }
  depends_on = [ helm_release.karpenter_crd ]
}
*/

# Lab 2, third apply
/*
resource "kubernetes_manifest" "karpenter_nodeclass" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2023"
      role = module.eks_karpenter.node_iam_role_name
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = "karpenter-lab"
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
          }
        }
      ]
    }
  }
  depends_on = [ helm_release.karpenter_crd ]
}

resource "kubernetes_manifest" "karpenter_nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          nodeClassRef = {
            apiVersion = "karpenter.k8s.aws/v1beta1"
            kind = "EC2NodeClass"
            name = kubernetes_manifest.karpenter_nodeclass.manifest.metadata.name
          }
          taints = [
            {
              key = "karpenter-lab"
              effect = "NoSchedule"
            }
          ]
          requirements = [
            {
              key = "karpenter.k8s.aws/instance-family"
              operator = "In"
              values = var.karpenter_nodepool_instance_families
            },
            {
              key = "karpenter.sh/capacity-type"
              operator = "In"
              values = [ "on-demand" ]
            }
          ]
        }
      }
    }
  }
  depends_on = [ kubernetes_manifest.karpenter_nodeclass ]
}
*/