# Nomad
variable "nomad_provider_address" {
  type        = string
  description = "Nomad address"
  default     = "http://127.0.0.1:4646"
}
variable "nomad_datacenters" {
  type        = list(string)
  description = "Nomad data centers"
  default     = ["dc1"]
}
variable "nomad_namespace" {
  type        = string
  description = "[Enterprise] Nomad namespace"
  default     = "default"
}
variable "nomad_job_name" {
  type        = string
  description = "Nomad job name"
  default     = "presto"
}

variable "local_docker_image" {
  type        = bool
  description = "Switch for nomad jobs to use artifact for image lookup"
  default     = false
}

variable "mode" {
  type        = string
  description = "Switch for nomad jobs to use cluster or standalone deployment"
  default     = "standalone"
  validation {
    condition     = var.mode == "standalone" || var.mode == "cluster"
    error_message = "Valid modes: \"cluster\" or \"standalone\"."
  }
}

# presto
variable "cluster_shared_secret" {
  type        = string
  description = "Shared secret between coordinator and workers"
}

variable "service_name" {
  type        = string
  description = "Presto service name"
  default     = "presto"
}

variable "coordinator" {
  type        = bool
  description = "Include a coordinator in addition to the workers. Set this to `false` when extending an existing cluster"
  default     = true
}

variable "workers" {
  type        = number
  description = "cluster: Number of nomad worker nodes"
  default     = 1
}

variable "debug" {
  type        = bool
  description = "Turn on debug logging in presto nodes"
  default     = false
}

variable "consul_http_addr" {
  type        = string
  description = "Address to consul, resolvable from the container. e.g. http://127.0.0.1:8500"
}

variable "memory" {
  type        = number
  description = "Memory allocation for presto nodes"
  default     = 1024
  validation {
    condition = var.memory >= 738
    error_message = "Presto can not run with less than 512MB of memory. 256MB is subtracted for OS. Total must be at least 738MB."
  }
}

variable "docker_image" {
  type        = string
  description = "Presto docker image"
  default     = "prestosql/presto:341"
}

variable "container_environment_variables" {
  type        = list(string)
  description = "Presto environment variables"
  default     = [""]
}

variable "hivemetastore" {
  type = object({
    service_name = string,
    port         = number,
  })
  default = {
    service_name = "hive-metastore"
    port         = 9083
  }
  description = "Hivemetastore data-object contains service_name and port"
}

variable "minio" {
  type = object({
    service_name = string,
    port         = number,
    access_key   = string,
    secret_key   = string,
  })
  description = "Minio data-object contains service_name, port, access_key and secret_key"
}
