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


data "template_file" "template_nomad_job_presto" {
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

    # Memory allocations for presto is automatically tuned based on memory sizing set at the task driver level in nomad.
    # Based on web-resources and presto community slack, we choose to allocate 75% (up to 80% should work) to the JVM
    # Resources: https://prestosql.io/blog/2020/08/27/training-performance.html
    #            https://prestosql.io/docs/current/admin/properties-memory-management.html
    presto_xmx_memory     = floor( var.memory * 0.75 )
    presto_query_max_memory = floor( ( floor( var.memory * 0.75 ) * 0.1 ) * var.workers )

    #Custom plugin for consul connect integration
    consul_connect_plugin_version = var.consul_connect_plugin_version

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
  jobspec = data.template_file.template_nomad_job_presto.rendered
  detach  = false
}
