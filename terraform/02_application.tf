# =============================================================================
# Getting the k8s datasource
# =============================================================================

data "terraform_remote_state" "k8s" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket                      = "fr-par-p-oss-tfstate-do-not-delete"
    key                         = "landingzone/infrastructure-socle.tfstate"
    region                      = "fr-par"
    endpoint                    = "https://s3.fr-par.scw.cloud"
    skip_credentials_validation = true
    skip_region_validation      = true
  }
}

# =============================================================================
# Kubernetes - Provider Configuration
# =============================================================================

provider "kubernetes" {
  host                   = data.terraform_remote_state.k8s.outputs.k8s_host
  cluster_ca_certificate = data.terraform_remote_state.k8s.outputs.k8s_ca_certificate
  token                  = data.terraform_remote_state.k8s.outputs.k8s_token
}

# =============================================================================
# Kubernetes - Create Namespace
# =============================================================================

resource "kubernetes_namespace" "namespace" {
  depends_on = [time_sleep.wait_build_infra]
  metadata { name = "bookstack" }
  timeouts { delete = "10m" }
}

# =============================================================================
# Kubernetes - Create Service
# =============================================================================

resource "kubernetes_service" "service" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = "bookstack-service"
    namespace = kubernetes_namespace.namespace.metadata[0].name

    labels = {
      app          = "bookstack"
      environment  = terraform.workspace
      resourceType = "service"
    }
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 80
      target_port = "8080"
    }

    selector = { app = "bookstack" }
  }
}

# =============================================================================
# Kubernetes - Create TLS Secret
# =============================================================================

# TLS certificates
resource "kubernetes_secret" "tls_secret" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = "tls-cert"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  data = {
    "tls.crt" = file("${path.module}/configs/tls/cert.pem")
    "tls.key" = file("${path.module}/configs/tls/cert.key")
  }
  type = "kubernetes.io/tls"
}

# =============================================================================
# Kubernetes - Create IngressRoute in Traefik
# =============================================================================

resource "null_resource" "bookstack_ingress" {
  triggers = {
    ingress_file_sha1 = sha1(file("${path.module}/configs/ingress.yaml"))
    kubeconfig        = base64encode(data.terraform_remote_state.k8s.outputs.k8s_kubeconfig)
    ingress_file_path = terraform.workspace == "production" ? "terraform/configs/ingress.yaml" : "terraform/configs/ingress-dev.yaml"
  }
  depends_on = [kubernetes_namespace.namespace, kubernetes_secret.tls_secret]
  provisioner "local-exec" {
    command     = "kubectl apply -f $FILE_PATH --kubeconfig <(echo $KUBECONFIG | base64 -d)"
    interpreter = ["/bin/bash", "-c"]

    environment = {
      KUBECONFIG = base64encode(data.terraform_remote_state.k8s.outputs.k8s_kubeconfig)
      FILE_PATH  = self.triggers.ingress_file_path
    }
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "kubectl delete -f $FILE_PATH --kubeconfig <(echo $KUBECONFIG | base64 -d)"
    interpreter = ["/bin/bash", "-c"]

    environment = {
      KUBECONFIG = self.triggers.kubeconfig
      FILE_PATH  = self.triggers.ingress_file_path
    }
  }
}

# =============================================================================
# Kubernetes - Create ConfigMap
# =============================================================================

resource "kubernetes_config_map" "config_map" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = "bookstack-config-configmap"
    namespace = kubernetes_namespace.namespace.metadata[0].name

    labels = {
      app          = "bookstack"
      environment  = terraform.workspace
      resourceType = "persistentVolumeClaim"
    }
  }

  data = {
    ".env" = templatefile("${path.module}/configs/configmap.yml", {
      app_url = terraform.workspace == "production" ? "https://wiki.example.com" : "https://wiki.dev.example.com"
      # Remote S3
      bucket_access_key = var.scw_bucket_access_key
      bucket_secret_key = var.scw_bucket_secret_key
      bucket_name       = scaleway_object_bucket.upload_bucket.name
      bucket_region     = var.region
      bucket_endpoint   = "s3.fr-par.scw.cloud"
      # SMTP configurations
      smtp_address      = var.smtp_address
      smtp_port         = var.smtp_port
      smtp_username     = var.smtp_username
      smtp_password     = var.smtp_password
      smtp_mailfrom     = "bookstack@${var.domain}"
      smtp_mailfromname = "BookStack"
    })
  }
}

# =============================================================================
# Kubernetes - Create Deployment
# =============================================================================

resource "kubernetes_deployment" "bookstack_deployment" {
  depends_on = [kubernetes_config_map.config_map]
  metadata {
    name      = "bookstack-deployment"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      app          = "bookstack"
      environment  = terraform.workspace
      resourceType = "deployment"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "bookstack" }
    }

    template {
      metadata {
        namespace = kubernetes_namespace.namespace.metadata[0].name
        labels = {
          app          = "bookstack"
          environment  = terraform.workspace
          resourceType = "pod"
        }
      }

      spec {
        volume {
          name = "config"
          config_map {
            name = "bookstack-config-configmap"
            items {
              key  = ".env"
              path = ".env"
            }
          }
        }
        volume {
          name = "log-laravel"
          empty_dir {}
        }
        volume {
          name = "log-apache"
          empty_dir {}
        }
        init_container {
          name    = "create-log-files"
          image   = "busybox:1.33.0"
          command = ["/bin/sh", "-c", "touch /var/www/bookstack/storage/logs/laravel.log && touch /var/log/apache2/access.log && touch /var/log/apache2/error.log"]
          volume_mount {
            name       = "log-laravel"
            mount_path = "/var/www/bookstack/storage/logs/"
          }
          volume_mount {
            name       = "log-apache"
            mount_path = "/var/log/apache2/"
          }
        }
        init_container {
          name    = "update-permissions-log-file"
          image   = "busybox:1.33.0"
          command = ["/bin/sh", "-c", "chmod 777 /var/www/bookstack/storage/logs/laravel.log && chmod 777 /var/log/apache2/access.log && chmod 777 /var/log/apache2/error.log"]
          volume_mount {
            name       = "log-laravel"
            mount_path = "/var/www/bookstack/storage/logs/"
          }
          volume_mount {
            name       = "log-apache"
            mount_path = "/var/log/apache2/"
          }
        }
        container {
          name    = "access-log"
          image   = "busybox:1.33.0"
          command = ["/bin/sh", "-c", "tail -f /var/log/apache2/access.log"]
          volume_mount {
            name       = "log-apache"
            mount_path = "/var/log/apache2/"
          }
        }
        container {
          name    = "error-log"
          image   = "busybox:1.33.0"
          command = ["/bin/sh", "-c", "tail -f /var/log/apache2/error.log"]
          volume_mount {
            name       = "log-apache"
            mount_path = "/var/log/apache2/"
          }
        }
        container {
          name    = "laravel-log"
          image   = "busybox:1.33.0"
          command = ["/bin/sh", "-c", "tail -f /var/www/bookstack/storage/logs/laravel.log"]
          volume_mount {
            name       = "log-laravel"
            mount_path = "/var/www/bookstack/storage/logs/"
          }
        }
        container {
          name  = "bookstack"
          image = "solidnerd/bookstack:0.30.4"
          port {
            name           = "web"
            container_port = 8080
            protocol       = "TCP"
          }
          env {
            name  = "TZ"
            value = "Europe/Paris"
          }
          env {
            name  = "DB_HOST"
            value = "${scaleway_rdb_instance.bookstack_mysql.endpoint_ip}:${scaleway_rdb_instance.bookstack_mysql.endpoint_port}"
          }
          env {
            name  = "DB_DATABASE"
            value = scaleway_rdb_user.bookstack_user.name
          }
          env {
            name  = "DB_USERNAME"
            value = scaleway_rdb_user.bookstack_user.name
          }
          env {
            name  = "DB_PASSWORD"
            value = scaleway_rdb_user.bookstack_user.password
          }
          volume_mount {
            name       = "config"
            mount_path = "/var/www/bookstack/.env"
            sub_path   = ".env"
          }
          volume_mount {
            name       = "log-laravel"
            mount_path = "/var/www/bookstack/storage/logs/"
          }
          volume_mount {
            name       = "log-apache"
            mount_path = "/var/log/apache2/"
          }
          liveness_probe {
            http_get {
              path = "/"
              port = "8080"
            }
          }
          readiness_probe {
            http_get {
              path = "/"
              port = "8080"
            }
          }
        }

        restart_policy = "Always"
        node_selector  = { "k8s.scaleway.com/pool-name" = data.terraform_remote_state.k8s.outputs.k8s_pool_names["medium"].name }
      }
    }
  }
}
