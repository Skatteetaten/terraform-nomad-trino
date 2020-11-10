locals {
  nomad_namespace   = "default"
  nomad_datacenters = ["dc1"]

  presto = {
    shared_secret_provider   = "user"
    vault_kv_policy_name     = "kv-secret"
    vault_kv_path            = "secret/data/presto"
    vault_kv_secret_key_name = "cluster_shared_secret"
    service_name             = "presto"
  }

  hivemetastore = {
    service_name = module.hive.service_name
    port         = 9083 # todo: add output var
  }

  minio = {
    service_name = module.minio.minio_service_name
    port         = 9000 # todo: add output var
    access_key   = module.minio.minio_access_key
    secret_key   = module.minio.minio_secret_key
  }
}

module "presto" {
  depends_on = [
    module.minio,
    module.hive
  ]

  source = "../.."

  nomad_job_name         = local.presto.service_name
  nomad_datacenters      = local.nomad_datacenters
  nomad_namespace        = local.nomad_namespace
  shared_secret_provider = local.presto.shared_secret_provider

  shared_secret_vault = {
    vault_kv_policy_name     = local.presto.vault_kv_policy_name
    vault_kv_path            = local.presto.vault_kv_path
    vault_kv_secret_key_name = local.presto.vault_kv_secret_key_name
  }

  service_name          = local.presto.service_name
  mode                  = "standalone"
  workers               = 1
  consul_http_addr      = "http://10.0.3.10:8500"
  debug                 = true
  use_canary            = true

  minio                 = local.minio
  hivemetastore         = local.hivemetastore
}

module "minio" {
  source = "github.com/fredrikhgrelland/terraform-nomad-minio.git?ref=0.2.0"

  # nomad
  nomad_datacenters = local.nomad_datacenters
  nomad_namespace   = local.nomad_namespace
  nomad_host_volume = "persistence-minio"

  # minio
  service_name                    = "minio"
  host                            = "127.0.0.1"
  port                            = 9000
  container_image                 = "minio/minio:latest" # todo: avoid using tag latest in future releases
  access_key                      = "minio"
  secret_key                      = "minio123"
  buckets                         = ["default", "hive"]
  container_environment_variables = ["JUST_EXAMPLE_VAR1=some-value", "ANOTHER_EXAMPLE2=some-other-value"]
  use_host_volume                 = true
  data_dir                        = "/minio/data"

  # mc
  mc_service_name                    = "mc"
  mc_container_image                 = "minio/mc:latest" # todo: avoid using tag latest in future releases
  mc_container_environment_variables = ["JUST_EXAMPLE_VAR3=some-value", "ANOTHER_EXAMPLE4=some-other-value"]
}

module "postgres" {
  source = "github.com/fredrikhgrelland/terraform-nomad-postgres.git?ref=0.2.0"

  # nomad
  nomad_datacenters = local.nomad_datacenters
  nomad_namespace   = local.nomad_namespace
  nomad_host_volume = "persistence-postgres"

  # postgres
  service_name                    = "postgres"
  container_image                 = "postgres:12-alpine"
  container_port                  = 5432
  admin_user                      = "hive"
  admin_password                  = "hive"
  database                        = "metastore"
  container_environment_variables = ["PGDATA=/var/lib/postgresql/data"]
  use_host_volume                 = true
  volume_destination              = "/var/lib/postgresql/data"
}

module "hive" {
  source = "github.com/fredrikhgrelland/terraform-nomad-hive.git?ref=0.2.0"

  # nomad
  nomad_datacenters  = local.nomad_datacenters
  nomad_namespace    = local.nomad_namespace
  local_docker_image = false

  # hive
  use_canary          = false
  hive_service_name   = "hive-metastore"
  hive_container_port = 9083
  hive_docker_image   = "fredrikhgrelland/hive:3.1.0"
  resource = {
    cpu     = 500,
    memory  = 1024
  }

  #support CSV -> https://towardsdatascience.com/load-and-query-csv-file-in-s3-with-presto-b0d50bc773c9
  #metastore.storage.schema.reader.impl=org.apache.hadoop.hive.metastore.SerDeStorageSchemaReader
  hive_container_environment_variables = [
    "HIVE_SITE_CONF_metastore_storage_schema_reader_impl=org.apache.hadoop.hive.metastore.SerDeStorageSchemaReader"
  ]

  # hive - minio
  hive_bucket = {
    default = "default",
    hive    = "hive"
  }
  minio_service = {
    service_name = module.minio.minio_service_name,
    port         = 9000,
    access_key   = module.minio.minio_access_key,
    secret_key   = module.minio.minio_secret_key,
  }

  # hive - postgres
  postgres_service = {
    service_name  = module.postgres.service_name
    port          = module.postgres.port
    database_name = module.postgres.database_name
    username      = module.postgres.username
    password      = module.postgres.password
  }

  depends_on = [
    module.minio,
    module.postgres
  ]
}
