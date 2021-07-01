# Nomad
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
  default     = "trino"
}

variable "local_docker_image" {
  type        = bool
  description = "Switch for nomad jobs to use artifact for image lookup"
  default     = false
}

variable "consul_docker_image" {
  type        = string
  description = "Consul docker image"
  default     = "consul:1.9"
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

# trino
variable "shared_secret_user" {
  type        = string
  description = "Shared secret provided by user"
  default     = "defaulttrinosecret"
  validation {
    condition     = length(var.shared_secret_user) >= 12
    error_message = "The length of the shared secret must be 12 characters or more."
  }
}

variable "vault_secret" {
  type = object({
    use_vault_provider         = bool,
    vault_kv_policy_name       = string,
    vault_kv_path              = string,
    vault_kv_field_secret_name = string
  })
  description = "Set of properties to be able fetch shared cluster secret from vault"
  default = {
    use_vault_provider         = true
    vault_kv_policy_name       = "kv-secret"
    vault_kv_path              = "secret/data/path/to/cluster-shared-secret/trino"
    vault_kv_field_secret_name = "cluster_shared_secret"
  }
}

variable "service_name" {
  type        = string
  description = "Trino service name"
  default     = "trino"
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
  description = "Turn on debug logging in trino nodes"
  default     = false
}

variable "consul_http_addr" {
  type        = string
  description = "Address to consul, resolvable from the container. e.g. http://127.0.0.1:8500"
}

variable "docker_image" {
  type        = string
  description = "Trino docker image"
  default     = "trinodb/trino:354"
}

variable "consul_connect_plugin" {
  type        = bool
  description = "Deploy consul connect plugin for trino"
  default     = true
}

variable "consul_connect_plugin_version" {
  type        = string
  description = "Version of the consul connect plugin for trino (on maven central) src here: https://github.com/gugalnikov/trino-consul-connect"
  default     = "2.2.0"
}

variable "consul_connect_plugin_artifact_source" {
  type        = string
  description = "Artifact URI source"
  default     = "https://oss.sonatype.org/service/local/repositories/releases/content/io/github/gugalnikov/trino-consul-connect"
}

variable "container_environment_variables" {
  type        = list(string)
  description = "Trino environment variables"
  default     = [""]
}

variable "use_canary" {
  type        = bool
  description = "Uses canary deployment for Trino"
  default     = false
}

variable "resource" {
  type = object({
    cpu    = number,
    memory = number
  })
  default = {
    cpu    = 500,
    memory = 1024
  }
  description = "Trino resources"
  validation {
    condition     = var.resource.cpu >= 500 && var.resource.memory >= 768
    error_message = "Trino can not run with less than 300Mhz CPU and less than 512MB of memory. 256MB is subtracted for OS. Total must be at least 768MB."
  }
}

variable "resource_proxy" {
  type = object({
    cpu    = number,
    memory = number
  })
  default = {
    cpu    = 200,
    memory = 128
  }
  description = "Trino proxy resources"
  validation {
    condition     = var.resource_proxy.cpu >= 200 && var.resource_proxy.memory >= 128
    error_message = "Proxy resource must be at least: cpu=200, memory=128."
  }
}

variable "hive_config_properties" {
  type        = list(string)
  description = "Custom hive configuration properties"
  default     = [""]
}

variable "trino_memory_connector" {
  type = object({
    use_memory_connector = bool
    connector_memory_max_data_per_node = string
  })
  default = {
    use_memory_connector = false,
    connector_memory_max_data_per_node = "128MB"
  }
  description = "Turn on or off memory connector in Trino, and its memory limit for pages stored in the connector per each node"
}
######
# Service dependencies
######

## Hive
variable "hivemetastore_service" {
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

## Minio
variable "minio_service" {
  type = object({
    service_name = string,
    port         = number,
    access_key   = string,
    secret_key   = string,
  })
  description = "Minio data-object contains service_name, port, access_key and secret_key"
}
variable "minio_vault_secret" {
  type = object({
    use_vault_provider         = bool,
    vault_kv_policy_name       = string,
    vault_kv_path              = string,
    vault_kv_field_access_name = string,
    vault_kv_field_secret_name = string
  })
  description = "Set of properties to be able to fetch secret from vault"
  default = {
    use_vault_provider         = false
    vault_kv_policy_name       = "kv-secret"
    vault_kv_path              = "secret/data/dev/trino"
    vault_kv_field_access_name = "access_key"
    vault_kv_field_secret_name = "secret_key"
  }
}

# Postgres
variable "postgres_service" {
  type = object({
    service_name  = string,
    port          = number,
    username      = string,
    password      = string,
    database_name = string,
  })
  description = "Postgres data-object contains service_name, port, username, password and database_name"
}
variable "postgres_vault_secret" {
  type = object({
    use_vault_provider      = bool,
    vault_kv_policy_name    = string,
    vault_kv_path           = string,
    vault_kv_field_username = string,
    vault_kv_field_password = string
  })
  description = "Set of properties to be able to fetch Postgres secrets from vault"
  default = {
    use_vault_provider      = false
    vault_kv_policy_name    = "kv-secret"
    vault_kv_path           = "secret/data/dev/trino"
    vault_kv_field_username = "username"
    vault_kv_field_password = "password"
  }
}
