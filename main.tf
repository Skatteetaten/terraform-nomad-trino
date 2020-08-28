locals {
  datacenters = join(",", var.nomad_datacenters)
  presto_env_vars = join("\n",
    concat([
      "JUST_EXAMPLE_ENV=some-value",
    ], var.container_environment_variables)
  )
}

data "template_file" "template-nomad-job-presto" {
  template = file("${path.module}/conf/nomad/presto.hcl")

  vars = {
    nomad_job_name = var.nomad_job_name
    datacenters    = local.datacenters
    namespace      = var.nomad_namespace

    service_name = var.service_name
    port         = var.port
    image        = var.docker_image
    envs         = local.presto_env_vars

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
