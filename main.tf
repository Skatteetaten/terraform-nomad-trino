locals {
  datacenters = join(",", var.nomad_datacenters)
  presto_env_vars = join("\n",
    concat([
      "JUST_EXAMPLE_ENV=some-value",
    ], var.container_environment_variables)
  )

  template_standalone = file("${path.module}/conf/nomad/presto_standalone.hcl")
  template_cluster    = file("${path.module}/conf/nomad/presto.hcl")

  node_types = var.coordinator ? ["coordinator", "worker"] : ["worker"]
}


data "template_file" "template-nomad-job-presto" {
  template = var.mode == "standalone" ? local.template_standalone : local.template_cluster

  vars = {
    nomad_job_name = var.nomad_job_name
    datacenters    = local.datacenters
    namespace      = var.nomad_namespace

    service_name          = var.service_name
    node_types            = jsonencode(local.node_types)
    local_docker_image    = var.local_docker_image
    workers               = var.workers
    cluster_shared_secret = var.cluster_shared_secret
    docker_image          = var.docker_image
    envs                  = local.presto_env_vars
    debug                 = var.debug
    memory                = var.memory
    consul_http_addr      = var.consul_http_addr

    #hivemetastore
    hivemetastore_service_name = var.hivemetastore.service_name
    hivemetastore_port         = var.hivemetastore.port

    # minio
    minio_service_name = var.minio.service_name
    minio_port         = var.minio.port
    minio_access_key   = var.minio.access_key
    minio_secret_key   = var.minio.secret_key
  }
}

resource "nomad_job" "nomad-job-presto" {
  jobspec = data.template_file.template-nomad-job-presto.rendered
  detach  = false
}
