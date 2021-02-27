# Variables

variable "id" {
  type        = string
  description = "GCP project id"
}

variable "region" {
  type        = string
  description = "GCP region"
}

# Provider

provider "google" {
  credentials = file("test-01-305711-690c95c3aab9.json")
  project     = var.id
  region      = var.region
}

# Network

resource "google_compute_network" "vpc_network" {
  name                    = "vpc-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "k8s-subnet-1" {
  name          = "k8s-subnet-1"
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  secondary_ip_range {
    range_name    = "secondary-range-k8s-subnet-1"
    ip_cidr_range = "192.168.10.0/24"

  }
}

resource "google_compute_subnetwork" "k8s-subnet-2" {
  name          = "k8s-subnet-2"
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  secondary_ip_range {
    range_name    = "secondary-range-k8s-subnet-2"
    ip_cidr_range = "192.168.20.0/24"
  }
}

resource "google_compute_subnetwork" "k8s-subnet-3" {
  name          = "k8s-subnet-3"
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  secondary_ip_range {
    range_name    = "secondary-range-k8s-subnet-3"
    ip_cidr_range = "192.168.30.0/24"
  }
}

#----------------------------------------------------------------------------------
# K8-masters Instance Group
#----------------------------------------------------------------------------------

resource "google_compute_instance_group_manager" "k8_masters_manager" {
  name = "k8_masters_manager"

  base_instance_name = "k8_masters"
  zones = ["europe-west3-a",
    "europe-west3-c",
  "europe-west3-c", ]
  depends_on = [
    google_compute_network.vpc_network,
    google_compute_subnetwork.k8s-subnet-1,
    google_compute_subnetwork.k8s-subnet-2,
    google_compute_subnetwork.k8s-subnet-3,
  ]

  version {
    instance_template = google_compute_instance_template.k8_masters.id
  }

  target_pools = [google_compute_target_pool.k8_masters_target_pool.id]
  target_size  = 3

  named_port {
    name = "customHTTP"
    port = 8888
  }


}

resource "google_compute_target_pool" "k8_masters_target_pool" {
  name = "k8_masters_target_pool"

  instances = [
    "europe-west3-a/K8_master_instance1",
    "europe-west3-b/K8_master_instance2",
    "europe-west3-b/K8_master_instance2",
  ]
}

resource "google_compute_instance_template" "k8_masters" {
  name        = "k8-masters-template"
  description = "This template is used to create k8-masters instances."

  instance_description = "description assigned to instances"
  machine_type         = "e2-standard-2"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-9"
    auto_delete  = true
    boot         = true
    // backup the disk every day
    resource_policies = [google_compute_resource_policy.daily_backup.id]
  }

  // Use an existing disk resource
  disk {
    // Instance Templates reference disks by name, not self link
    source      = google_compute_disk.k8_masters_disk.name
    auto_delete = false
    boot        = false
  }

  network_interface {
    network_ip = google_compute_network.vpc_network.id
  }



  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = "terraform-admin@test-01-305711.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

data "google_compute_image" "master_image" {
  family  = "debian-9"
  project = "debian-cloud"
}

resource "google_compute_disk" "k8_masters_disk" {
  name  = "existing-disk"
  image = data.google_compute_image.master_image.self_link
  size  = 10
  type  = "network-ssd"
  zone  = "europe-west3-a"
}
resource "google_compute_resource_policy" "daily_backup" {
  name   = "every-day-4am"
  region = "europe-west3"
  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "04:00"
      }
    }
  }
}


#---------------------------------------------------------------------------------
# Compute instance group for workers
#---------------------------------------------------------------------------------

resource "google_compute_instance_group_manager" "k8_workers_manager" {
  name = "k8_workers_manager"

  base_instance_name = "k8_workers"
  zone = ["europe-west3-a",
    "europe-west3-c",
  "europe-west3-c", ]
  depends_on = [
    google_compute_network.vpc_network,
    google_compute_subnetwork.k8s-subnet-1,
    google_compute_subnetwork.k8s-subnet-2,
    google_compute_subnetwork.k8s-subnet-3,
  ]

  version {
    instance_template = google_compute_instance_template.k8_workers.id
  }

  target_pools = [google_compute_target_pool.k8_workers_target_pool.id]
  target_size  = 3

  named_port {
    name = "customHTTP"
    port = 8889
  }


}

resource "google_compute_target_pool" "k8_workers_target_pool" {
  name = "k8_workers_target_pool"

  instances = [
    "europe-west3-a/K8_worker_instance1",
    "europe-west3-b/K8_worker_instance2",
    "europe-west3-b/K8_worker_instance2",
  ]
}

resource "google_compute_instance_template" "k8_workers" {
  name        = "k8-workers-template"
  description = "This template is used to create k8-workers instances."

  instance_description = "description assigned to instances"
  machine_type         = "e2-standard-2"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-9"
    auto_delete  = true
    boot         = true
  }

  // Use an disk resource
  disk {
    // Instance Templates reference disks by name, not self link
    source      = google_compute_disk.k8_workers_disk.name
    auto_delete = false
    boot        = false
  }

  network_interface {
    network_ip = google_compute_network.vpc_network.id

  }


  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = "terraform-admin@test-01-305711.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

data "google_compute_image" "worker_image" {
  family  = "debian-9"
  project = "debian-cloud"
}

resource "google_compute_disk" "k8_workers_disk" {
  name  = "existing-disk"
  image = data.google_compute_image.worker_image.self_link
  size  = 10
  type  = "network-hdd"
  zone  = "europe-west3-b"

}


# Compute instance group for ingresses

resource "google_compute_instance_group_manager" "k8_ingresses_manager" {
  name = "k8_ingresses_manager"

  base_instance_name = "k8_ingresses"
  zone = ["europe-west3-a",
    "europe-west3-c",
  "europe-west3-c", ]
  depends_on = [
    google_compute_network.vpc_network,
    google_compute_subnetwork.k8s-subnet-1,
    google_compute_subnetwork.k8s-subnet-2,
    google_compute_subnetwork.k8s-subnet-3,
  ]

  version {
    instance_template = google_compute_instance_template.k8_ingresses.id
  }

  target_pools = [google_compute_target_pool.k8_ingresses_target_pool.id]
  target_size  = 2

  named_port {
    name = "customHTTP"
    port = 8890
  }

}

resource "google_compute_target_pool" "k8_ingresses_target_pool" {
  name = "k8_ingresses_target_pool"

  instances = [
    "europe-west3-a/K8_ingress_instance1",
    "europe-west3-b/K8_ingress_instance2",
  ]
}

resource "google_compute_instance_template" "k8_ingresses" {
  name        = "k8-ingresses-template"
  description = "This template is used to create k8-ingresses instances."

  instance_description = "description assigned to instances"
  machine_type         = "e2-standard-2"
  can_ip_forward       = false

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = "debian-cloud/debian-9"
    auto_delete  = true
    boot         = true
  }

  // Use an existing disk resource
  disk {
    // Instance Templates reference disks by name, not self link
    source      = google_compute_disk.k8_ingresses_disk.name
    auto_delete = false
    boot        = false
  }

  network_interface {
    network_ip = google_compute_network.vpc_network.id

  }


  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = "terraform-admin@test-01-305711.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

data "google_compute_image" "ingress_image" {
  family  = "debian-9"
  project = "debian-cloud"
}

resource "google_compute_disk" "k8_ingresses_disk" {
  name  = "existing-disk"
  image = data.google_compute_image.ingress_image.self_link
  size  = 10
  type  = "network-hdd"
  zone  = "europe-west3-c"
}


#----------------------------------------------------------------------
# Load balancer for ingresses
#----------------------------------------------------------------------

resource "google_compute_forwarding_rule" "external_load_balancing" {
  depends_on = [google_compute_instance_group_manager.k8_ingresses_manager]
  name       = "k8s-load-balancer"
  region     = var.region

  ip_protocol           = "HTTP"
  load_balancing_scheme = "External"
  port_range            = "80"
  network               = google_compute_network.vpc_network
  subnetwork = [google_compute_subnetwork.k8s-subnet-1,
    google_compute_subnetwork.k8s-subnet-2,
    google_compute_subnetwork.k8s-subnet-3,
  ]
  target       = google_compute_instance_group_manager.k8_ingresses_manager.id
  network_tier = "STANDARD"

}
resource "google_compute_health_check" "autohealing_external_load_balancing" {
  name                = "external_load_balancing"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  http_health_check {
    request_path = "/healthz"
    port         = "8082"
  }
}

# Bucket for storing cluster backups
resource "google_storage_bucket" "backup_bucket" {
  name          = "backup_bucket"
  force_destroy = true
}

# Output values

output "google_compute_instance_group_manager_k8_masters_public_ips" {
  description = "Public IP addresses for master-nodes"
  value = [
    google_compute_instance_group_manager.k8_masters_manager.instance_template,
    google_compute_instance_template.k8_masters.network_interface.0.alias_ip_range,
  ]
}
output "google_compute_instance_group_manager_k8_masters_private_ips" {
  description = "Private IP addresses for master-nodes"
  value = [
    google_compute_instance_group_manager.k8_masters_manager.instance_template,
    google_compute_instance_template.k8_masters.network_interface.0.network_ip,
  ]
}
output "google_compute_instance_group_manager_k8_workers_public_ips" {
  description = "Public IP addresses for worker-nodes"
  value = [
    google_compute_instance_group_manager.k8_workers_manager.instance_template,
    google_compute_instance_template.k8_workers.network_interface.0.alias_ip_range,
  ]
}

output "google_compute_instance_group_manager_k8_workers_private_ips" {
  description = "Private IP addresses for worker-nodes"
  value = [
    google_compute_instance_group_manager.k8_workers_manager.instance_template,
    google_compute_instance_template.k8_workers.network_interface.0.network_ip,
  ]
}

output "instance_group_ingresses_public_ips" {
  description = "Public IP addresses for ingress-nodes"
  value = [
    google_compute_instance_group_manager.k8_ingresses_manager.instance_template,
    google_compute_instance_template.k8_ingresses.network_interface.alias_ip_range,
  ]
}

output "instance_group_ingresses_private_ips" {
  description = "Private IP addresses for ingress-nodes"
  value = [
    google_compute_instance_group_manager.k8_ingresses_manager.instance_template,
    google_compute_instance_template.k8_ingresses.network_interface.network_ip,
  ]
}

output "load_balancer_public_ip" {
  description = "Public IP address of load balancer"
  value       = google_compute_forwarding_rule.external_load_balancing.ip_address
}