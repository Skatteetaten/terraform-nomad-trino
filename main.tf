locals {
  datacenters = join(",", var.nomad_datacenters)
  trino_env_vars = join("\n",
    concat([
      "EXAMPLE_ENV=some-value",
    ], var.container_environment_variables)
  )
  hive_config_properties = join("\n",
    concat(var.hive_config_properties)
  )

  template_standalone       = file("${path.module}/conf/nomad/trino_standalone.hcl")
  template_cluster          = file("${path.module}/conf/nomad/trino.hcl")
  consul_connect_plugin_uri = "${var.consul_connect_plugin_artifact_source}/${var.consul_connect_plugin_version}/trino-consul-connect-${var.consul_connect_plugin_version}-jar-with-dependencies.jar"
  node_types                = var.coordinator ? ["coordinator", "worker"] : ["worker"]

  vault_provider = var.vault_secret.use_vault_provider || var.minio_vault_secret.use_vault_provider || var.postgres_vault_secret.use_vault_provider
  vault_kv_policy_name_set = jsonencode(
    distinct(
      concat(
        [var.vault_secret.vault_kv_policy_name],
        [var.minio_vault_secret.vault_kv_policy_name],
        [var.postgres_vault_secret.vault_kv_policy_name]
      )
    )
  )
}

data "template_file" "template_nomad_job_trino" {
  template = var.mode == "standalone" ? local.template_standalone : local.template_cluster

  vars = {
    # nomad
    nomad_job_name = var.nomad_job_name
    datacenters    = local.datacenters
    namespace      = var.nomad_namespace

    # policies if vault secret kv provider is ON
    use_vault_provider = local.vault_provider
    vault_policy_array = local.vault_kv_policy_name_set

    # trino
    service_name               = var.service_name
    node_types                 = jsonencode(local.node_types)
    local_docker_image         = var.local_docker_image
    consul_image               = var.consul_docker_image
    shared_secret_user         = var.shared_secret_user
    use_vault_secret_provider  = var.vault_secret.use_vault_provider
    vault_kv_policy_name       = var.vault_secret.vault_kv_policy_name
    vault_kv_path              = var.vault_secret.vault_kv_path
    vault_kv_field_secret_name = var.vault_secret.vault_kv_field_secret_name
    workers                    = var.workers
    docker_image               = var.docker_image
    envs                       = local.trino_env_vars
    hive_config_properties     = local.hive_config_properties
    debug                      = var.debug
    memory                     = var.resource.memory
    cpu                        = var.resource.cpu
    consul_http_addr           = var.consul_http_addr
    use_canary                 = var.use_canary
    cpu_proxy                  = var.resource_proxy.cpu
    memory_proxy               = var.resource_proxy.memory
    use_memory_connector       = var.trino_memory_connector.use_memory_connector
    connector_memory_max_data_per_node          = var.trino_memory_connector.connector_memory_max_data_per_node

    # Memory allocations for trino is automatically tuned based on memory sizing set at the task driver level in nomad.
    # Based on web-resources and trino community slack, we choose to allocate 75% (up to 80% should work) to the JVM
    # Resources: https://trinosql.io/blog/2020/08/27/training-performance.html
    #            https://trinosql.io/docs/current/admin/properties-memory-management.html
    trino_xmx_memory       = floor(var.resource.memory * 0.75)
    trino_query_max_memory = floor((floor(var.resource.memory * 0.75) * 0.1) * var.workers)

    #Custom plugin for consul connect integration
    consul_connect_plugin     = var.consul_connect_plugin
    consul_connect_plugin_uri = local.consul_connect_plugin_uri

    #hivemetastore
    hivemetastore_service_name = var.hivemetastore_service.service_name
    hivemetastore_port         = var.hivemetastore_service.port

    # minio
    minio_service_name = var.minio_service.service_name
    minio_port         = var.minio_service.port
    minio_access_key   = var.minio_service.access_key
    minio_secret_key   = var.minio_service.secret_key

    # if creds are provided by vault
    minio_use_vault_provider         = var.minio_vault_secret.use_vault_provider
    minio_vault_kv_policy_name       = var.minio_vault_secret.vault_kv_policy_name # This var is appended to local.vault_kv_policy_name_set
    minio_vault_kv_path              = var.minio_vault_secret.vault_kv_path
    minio_vault_kv_field_access_name = var.minio_vault_secret.vault_kv_field_access_name
    minio_vault_kv_field_secret_name = var.minio_vault_secret.vault_kv_field_secret_name

    # postgres
    postgres_service_name  = var.postgres_service.service_name
    postgres_port          = var.postgres_service.port
    postgres_username      = var.postgres_service.username
    postgres_password      = var.postgres_service.password
    postgres_database_name = var.postgres_service.database_name
    # if creds ar provided by vault
    postgres_use_vault_provider      = var.postgres_vault_secret.use_vault_provider
    postgres_vault_kv_policy_name    = var.postgres_vault_secret.vault_kv_policy_name
    postgres_vault_kv_path           = var.postgres_vault_secret.vault_kv_path
    postgres_vault_kv_field_username = var.postgres_vault_secret.vault_kv_field_username
    postgres_vault_kv_field_password = var.postgres_vault_secret.vault_kv_field_password
  }
}

resource "nomad_job" "nomad_job_trino" {
  jobspec = data.template_file.template_nomad_job_trino.rendered
  detach  = false
}
