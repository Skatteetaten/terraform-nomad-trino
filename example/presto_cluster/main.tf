locals {
  nomad_datacenters = ["dc1"]
  nomad_namespace   = "default"
}

module "presto" {
  source = "../.."

  depends_on = [
    module.minio,
    module.hive
  ]

  # nomad
  nomad_job_name    = "presto"
  nomad_datacenters = local.nomad_datacenters
  nomad_namespace   = local.nomad_namespace

  resource = {
    cpu = 500
    memory = 1024
  }

  resource_proxy = {
    cpu = 200
    memory = 128
  }


  # Vault provided credentials
  vault_secret = {
    use_vault_provider        = true
    vault_kv_policy_name      = "kv-secret"
    vault_kv_path             = "secret/data/dev/presto"
    vault_kv_secret_key_name  = "cluster_shared_secret"
  }

  service_name     = "presto"
  mode             = "cluster"
  workers          = 1
  consul_http_addr = "http://10.0.3.10:8500"
  debug            = true
  use_canary       = true

  # other
  hivemetastore_service = {
    service_name = module.hive.service_name
    port         = module.hive.port
  }

  minio_service = {
    service_name = module.minio.minio_service_name
    port         = module.minio.minio_port
    access_key   = ""
    secret_key   = ""
  }

  # Vault provided credentials
  minio_vault_secret = {
    use_vault_provider        = true
    vault_kv_policy_name      = "kv-secret"
    vault_kv_path             = "secret/data/dev/minio"
    vault_kv_access_key_name  = "access_key"
    vault_kv_secret_key_name  = "secret_key"
  }

}

module "minio" {
  source = "github.com/fredrikhgrelland/terraform-nomad-minio.git?ref=0.3.0"

  # nomad
  nomad_datacenters = local.nomad_datacenters
  nomad_namespace   = local.nomad_namespace
  nomad_host_volume = "persistence-minio"

  # minio
  service_name    = "minio"
  host            = "127.0.0.1"
  port            = 9000
  container_image = "minio/minio:latest" # todo: avoid using tag latest in future releases

  # Vault provided credentials
  # todo: follow naming convention issue https://github.com/fredrikhgrelland/terraform-nomad-minio/issues/87
  vault_secret = {
    use_vault_provider   = true
    vault_kv_policy_name = "kv-secret"
    vault_kv_path        = "secret/data/dev/minio"
    vault_kv_access_key  = "access_key"
    vault_kv_secret_key  = "secret_key"
  }

  # Credentials will be provided via vault > vault_secret.use_vault_provider = true
  access_key = ""
  secret_key = ""

  data_dir                        = "/minio/data"
  buckets                         = ["default", "hive"]
  container_environment_variables = ["JUST_EXAMPLE_VAR1=some-value", "ANOTHER_EXAMPLE2=some-other-value"]
  use_host_volume                 = true
  use_canary                      = true

  # mc
  mc_service_name                    = "mc"
  mc_container_image                 = "minio/mc:latest" # todo: avoid using tag latest in future releases
  mc_container_environment_variables = ["JUST_EXAMPLE_VAR3=some-value", "ANOTHER_EXAMPLE4=some-other-value"]
}

module "postgres" {
  source = "github.com/fredrikhgrelland/terraform-nomad-postgres.git?ref=0.3.0"

  # nomad
  nomad_datacenters = local.nomad_datacenters
  nomad_namespace   = local.nomad_namespace
  nomad_host_volume = "persistence-postgres"

  # postgres
  service_name    = "postgres"
  container_image = "postgres:12-alpine"
  container_port  = 5432

  # Vault provided credentials
  vault_secret = {
    use_vault_provider     = true
    vault_kv_policy_name   = "kv-secret"
    vault_kv_path          = "secret/data/dev/postgres"
    vault_kv_username_name = "username"
    vault_kv_password_name = "password"
  }

  # Credentials will be provided via vault > vault_secret.use_vault_provider = true
  admin_user                      = ""
  admin_password                  = ""

  database                        = "metastore"
  volume_destination              = "/var/lib/postgresql/data"
  use_host_volume                 = true
  use_canary                      = true
  container_environment_variables = ["PGDATA=/var/lib/postgresql/data/"]
}

module "hive" {
  source = "github.com/fredrikhgrelland/terraform-nomad-hive.git?ref=0.3.0"

  depends_on = [
    module.minio,
    module.postgres
  ]

  # nomad
  nomad_datacenters  = local.nomad_datacenters
  nomad_namespace    = local.nomad_namespace
  local_docker_image = false

  # hive
  use_canary                           = true
  hive_service_name                    = "hive-metastore"
  hive_container_port                  = 9083
  hive_docker_image                    = "fredrikhgrelland/hive:3.1.0"
  hive_container_environment_variables = ["SOME_EXAMPLE=example-value"]

  # Hive - Minio
  hive_bucket = {
    default = "default"
    hive    = "hive"
  }

  # Minio
  minio_service = {
    service_name = module.minio.minio_service_name
    port         = module.minio.minio_port
    access_key   = "", # will be ignored > minio_vault_secret.use_vault_provider = true
    secret_key   = ""  # will be ignored > minio_vault_secret.use_vault_provider = true
  }

  # Vault provided credentials
  minio_vault_secret = {
    use_vault_provider        = true
    vault_kv_policy_name      = "kv-secret"
    vault_kv_path             = "secret/data/dev/minio"
    vault_kv_access_key_name  = "access_key"
    vault_kv_secret_key_name  = "secret_key"
  }

  # Postgres
  postgres_service = {
    service_name  = module.postgres.service_name
    port          = module.postgres.port
    database_name = module.postgres.database_name
    username      = "" # will be ignored > postgres_vault_secret.use_vault_provider = true
    password      = "" # will be ignored > postgres_vault_secret.use_vault_provider = true
  }

  # Vault provided credentials
  postgres_vault_secret = {
    use_vault_provider     = true
    vault_kv_policy_name   = "kv-secret"
    vault_kv_path          = "secret/data/dev/postgres"
    vault_kv_username_name = "username"
    vault_kv_password_name = "password"
  }
}
