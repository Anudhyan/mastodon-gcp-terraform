terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.6"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  backend "gcs" {
    bucket      = "interledger-social-terraform"
    prefix      = "terraform/state/mastodon-app"
    credentials = "../terraform-sa.json"
  }
}

provider "google" {
  project     = var.project
  credentials = var.credentials_file_path
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${var.dependencies.gke_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(var.dependencies.gke_ca_certificate)
}

# Prepare GKE ingress TLS certificate
resource "kubernetes_manifest" "managedcertificate_managed_cert" {
  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"

    metadata = {
      name      = var.tls_certificate_name
      namespace = var.kubernetes_namespace
    }

    spec = {
      domains = [
        var.local_domain
      ]
    }
  }
}

# Mastodon release on Kubernetes
provider "helm" {
  kubernetes = {
    host                   = "https://${var.dependencies.gke_endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(var.dependencies.gke_ca_certificate)
  }
}

resource "helm_release" "mastodon" {
  name       = "mastodon"
  namespace  = var.kubernetes_namespace
  chart      = "mastodon"
  repository = "https://mastodon.github.io/helm-charts/"
  version    = "1.2.7"

  create_namespace = true

  wait = false

  set = [
    {
      name  = "mastodon.createAdmin.enabled"
      value = var.create_admin
    },
    {
      name  = "mastodon.createAdmin.username"
      value = var.create_admin_username
    },
    {
      name  = "mastodon.createAdmin.email"
      value = var.create_admin_email
    },

    {
      name  = "mastodon.localDomain"
      value = var.local_domain
    },

    {
      name  = "mastodon.logLevel.rails"
      value = var.logLevel_rails
    },
    {
      name  = "mastodon.logLevel.streaming"
      value = var.logLevel_streaming
    },

    {
      name  = "mastodon.persistence.assets.accessMode"
      value = "ReadWriteMany"
    },
    {
      name  = "mastodon.persistence.system.accessMode"
      value = "ReadWriteMany"
    },

    {
      name  = "mastodon.s3.accessKeyId"
      value = var.dependencies.s3_access_key
    },
    {
      name  = "mastodon.s3.bucket"
      value = var.dependencies.gcs_name
    },
    {
      name  = "mastodon.s3.endpoint"
      value = "https://storage.googleapis.com"
    },
    {
      name  = "mastodon.s3.hostname"
      value = "storage.googleapis.com"
    },
    {
      name  = "mastodon.s3.region"
      value = var.dependencies.gcs_region
    },
    {
      name  = "mastodon.secrets.vapidPublicKey"
      value = var.vapid_public_key
    },

    {
      name  = "mastodon.smtp.auth_method"
      value = var.smtp_auth_method
    },
    {
      name  = "mastodon.smtp.domain"
      value = var.local_domain
    },
    {
      name  = "mastodon.smtp.enable_starttls"
      value = var.smtp_enable_starttls
    },
    {
      name  = "mastodon.smtp.from_address"
      value = var.smtp_from_address
    },
    {
      name  = "mastodon.smtp.openssl_verify_mode"
      value = var.smtp_openssl_verify_mode
    },
    {
      name  = "mastodon.smtp.port"
      value = var.smtp_port
    },
    {
      name  = "mastodon.smtp.server"
      value = var.smtp_server
    },

    {
      name  = "mastodon.trustedProxyIp"
      value = var.trusted_proxy_ip
    },

    {
      name  = "ingress.enabled"
      value = true
    },
    {
      name  = "httproute.enabled"
      value = false
    },
    {
      name  = "ingress.annotations.networking\\.gke\\.io/managed-certificates"
      value = var.tls_certificate_name
    },
    {
      name  = "ingress.annotations.kubernetes\\.io/ingress\\.global-static-ip-name"
      value = var.dependencies.ingress_ipv4_name
    },
    {
      name  = "ingress.hosts[0].host"
      value = var.local_domain
    },
    {
      name  = "ingress.hosts[0].paths[0].path"
      value = "/"
    },
    {
      name  = "ingress.hosts[0].paths[0].pathType"
      value = "Prefix"
    },
    {
      name  = "ingress.tls"
      value = "null"
    },

    {
      name  = "postgresql.hostname"
      value = var.dependencies.db_hostname
    },
    {
      name  = "postgresql.port"
      value = 5432
    },
    {
      name  = "postgresql.database"
      value = var.dependencies.db_name
    },
    {
      name  = "postgresql.username"
      value = var.dependencies.db_user
    },

    {
      name  = "redis.hostname"
      value = var.dependencies.redis_hostname
    },
    {
      name  = "redis.port"
      value = var.dependencies.redis_port
    },

    {
      name  = "elasticsearch.enabled"
      value = false
    },
  ]

  set_sensitive = [
    {
      name  = "mastodon.s3.secretAccessKey"
      value = var.dependencies.s3_access_secret
    },

    {
      name  = "mastodon.secrets.secretKeyBase"
      value = var.secret_key_base
    },
    {
      name  = "mastodon.secrets.vapidPrivateKey"
      value = var.vapid_private_key
    },
    {
      name  = "mastodon.secrets.arePrimaryKey"
      value = var.active_record_encryption_primary_key
    },
    {
      name  = "mastodon.secrets.areDeterministicKey"
      value = var.active_record_encryption_deterministic_key
    },
    {
      name  = "mastodon.secrets.areKeyDerivationSalt"
      value = var.active_record_encryption_key_derivation_salt
    },
    {
      name  = "mastodon.smtp.username"
      value = var.smtp_login
    },
    {
      name  = "mastodon.smtp.password"
      value = var.smtp_password
    },
    {
      name  = "postgresql.password"
      value = var.dependencies.db_pass
    },
    {
      name  = "redis.auth.password"
      value = var.dependencies.redis_auth_string
    },
  ]

  values = [
    yamlencode(var.node_selector != null ? { nodeSelector : var.node_selector } : {})
  ]
}

# Add ingress rule for redirecting http-to-https
resource "kubernetes_manifest" "frontendconfig_https_redirect" {
  manifest = {
    "apiVersion" = "networking.gke.io/v1beta1"
    "kind"       = "FrontendConfig"

    "metadata" = {
      "name"      = "https-redirect"
      "namespace" = var.kubernetes_namespace
    }

    "spec" = {
      "redirectToHttps" = {
        "enabled" = true
      }
    }
  }
}
