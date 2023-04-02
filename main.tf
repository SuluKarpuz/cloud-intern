

data "google_client_config" "provider" {}
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

provider "google" {
  credentials = file("service-account.json")
  project     = var.project_name
  region      = "europe-west1"
}


# Create VPC network for GKE
resource "google_compute_network" "vpc_network" {
  name                    = "kartaca-staj-vpc"
  auto_create_subnetworks = false

  routing_mode = "REGIONAL"
}

# Create subnetwork for GKE nodes
resource "google_compute_subnetwork" "gke_nodes_subnet" {
  name          = "kartaca-staj-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.vpc_network.self_link
}

# Create GKE cluster
resource "google_container_cluster" "primary" {
  name               = "kartaca-staj-cluster"
  location           = "europe-west1"
  remove_default_node_pool = true
  initial_node_count = 1
  
  
  subnetwork = google_compute_subnetwork.gke_nodes_subnet.self_link

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    
  }

  network = google_compute_network.vpc_network.self_link
}

# Create a Kubernetes deployment for our app
resource "kubernetes_deployment" "my-node-app" {
  depends_on = [
    google_container_cluster.primary
  ]
  metadata {
    name = "my-node-app"
  }

  spec {
    selector {
      match_labels = {
        app = "my-node-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "my-node-app"
        }
      }

      spec {
        container {
          name  = "my-node-app"
          image = "sulukarpuz/kartaja-staj"
          port {
            container_port = 80
            
          }
        }
      }
    }
  }
}

# Expose the Kubernetes deployment to the internet using a LoadBalancer service
resource "kubernetes_service" "my-node-app" {
  metadata {
    name = "my-node-app"
  }

  spec {
    selector = {
      app = "my-node-app"
    }
    type = "LoadBalancer"

    port {
      name = "http"
      port        = 80
      target_port = 80
    }

   
  }
}

# Output the IP address of the LoadBalancer service
output "ip_address" {
  value = "http://${kubernetes_service.my-node-app.status[0].load_balancer[0].ingress[0].ip}"
}
