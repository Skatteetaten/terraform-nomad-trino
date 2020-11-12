locals {
  datacenters = join(",", var.nomad_datacenters)
  presto_env_vars = join("\n",
    concat([
      "EXAMPLE_ENV=some-value",
    ], var.container_environment_variables)
  )

  template_standalone       = file("${path.module}/conf/nomad/presto_standalone.hcl")
  template_cluster          = file("${path.module}/conf/nomad/presto.hcl")
  consul_connect_plugin_uri = "${var.consul_connect_plugin_artifact_source}/${var.consul_connect_plugin_version}/presto-consul-connect-${var.consul_connect_plugin_version}-jar-with-dependencies.jar"
  node_types                = var.coordinator ? ["coordinator", "worker"] : ["worker"]
}

data "template_file" "template_nomad_job_presto" {
  template = var.mode == "standalone" ? local.template_standalone : local.template_cluster

  vars = {
    # nomad
    nomad_job_name = var.nomad_job_name
    datacenters    = local.datacenters
    namespace      = var.nomad_namespace

    # presto
    service_name              = var.service_name
    node_types                = jsonencode(local.node_types)
    local_docker_image        = var.local_docker_image
    shared_secret_user        = var.shared_secret_user
    use_vault_secret_provider = var.vault_secret.use_vault_secret_provider
    vault_kv_policy_name      = var.vault_secret.vault_kv_policy_name
    vault_kv_path             = var.vault_secret.vault_kv_path
    vault_kv_secret_key_name  = var.vault_secret.vault_kv_secret_key_name
    workers                   = var.workers
    docker_image              = var.docker_image
    envs                      = local.presto_env_vars
    debug                     = var.debug
    memory                    = var.resource.memory
    cpu                       = var.resource.cpu
    consul_http_addr          = var.consul_http_addr
    use_canary                = var.use_canary
    cpu_proxy                 = var.resource_proxy.cpu
    memory_proxy              = var.resource_proxy.memory

    # Memory allocations for presto is automatically tuned based on memory sizing set at the task driver level in nomad.
    # Based on web-resources and presto community slack, we choose to allocate 75% (up to 80% should work) to the JVM
    # Resources: https://prestosql.io/blog/2020/08/27/training-performance.html
    #            https://prestosql.io/docs/current/admin/properties-memory-management.html
    presto_xmx_memory       = floor(var.resource.memory * 0.75)
    presto_query_max_memory = floor((floor(var.resource.memory * 0.75) * 0.1) * var.workers)

    #Custom plugin for consul connect integration
    consul_connect_plugin     = var.consul_connect_plugin
    consul_connect_plugin_uri = local.consul_connect_plugin_uri

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

resource "nomad_job" "nomad_job_presto" {
  jobspec = data.template_file.template_nomad_job_presto.rendered
  detach  = false
}
