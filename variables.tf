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

# presto
variable "service_name" {
  type        = string
  description = "Presto service name"
  default     = "presto"
}

variable "port" {
  type        = number
  description = "Presto http port"
  default     = 8080
}

variable "docker_image" {
  type        = string
  description = "Presto docker image"
  default     = "prestosql/presto:333"
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
