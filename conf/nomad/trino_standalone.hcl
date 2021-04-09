job "${nomad_job_name}" {
  type = "service"
  datacenters   = "${datacenters}"
  namespace     = "${namespace}"

  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "12m"
    progress_deadline = "15m"
  %{ if use_canary }
    canary            = 1
    auto_promote      = true
    auto_revert       = true
  %{ endif }
    stagger           = "30s"
  }

  group "standalone" {
    count = 1

    network {
      mode = "bridge"
      port "healthcheck" {
        to = -1
      }
    }

    service {
      name = "${service_name}"
      port = 8080
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "${hivemetastore_service_name}"
              local_bind_port  = "${hivemetastore_port}"
            }
            upstreams {
              destination_name = "${minio_service_name}"
              local_bind_port  = "${minio_port}"
            }
            upstreams {
              destination_name = "${postgres_service_name}"
              local_bind_port  = "${postgres_port}"
            }
            expose {
              path {
                path            = "/v1/info"
                protocol        = "http"
                local_path_port = 8080
                listener_port   = "healthcheck"
              }
            }
          }
        }
        sidecar_task {
          resources {
            cpu    = "${cpu_proxy}"
            memory = "${memory_proxy}"
          }
        }
      }

      check {
        task     = "server"
        name     = "trino-hive-availability"
        type     = "script"
        command  = "trino"
        args     = ["--execute", "SHOW TABLES IN hive.default"]
        interval = "30s"
        timeout  = "15s"
      }
      check {
        name     = "trino-info"
        type     = "http"
        port     = "healthcheck"
        path     = "/v1/info"
        interval = "10s"
        timeout  = "2s"
      }
      check {
        name         = "trino-minio-availability"
        type         = "http"
        path         = "/minio/health/ready"
        port         = ${minio_port}
        interval     = "15s"
        timeout      = "5s"
        address_mode = "driver"
      }
      check {
        task     = "server"
        name     = "trino-postgres-availability"
        type     = "script"
        command  = "trino"
        args     = ["--execute", "SHOW TABLES FROM postgresql.public"]
        interval = "30s"
        timeout  = "15s"
      }
    }

    task "waitfor-hive-metastore" {
      restart {
        attempts = 100
        delay    = "5s"
      }
      lifecycle {
        hook = "prestart"
      }
      driver = "docker"
      resources {
        memory = 32
      }
      config {
        image = "${consul_image}"
        entrypoint = ["/bin/sh"]
        args = ["-c", "jq </local/service.json -e '.[].Status|select(. == \"passing\")'"]
        volumes = ["tmp/service.json:/local/service.json" ]
      }
      template {
        destination = "tmp/service.json"
        data = <<EOH
          {{- service "${hivemetastore_service_name}" | toJSON -}}
        EOH
      }
    }

    task "waitfor-minio" {
      restart {
        attempts = 100
        delay    = "5s"
      }
      lifecycle {
        hook = "prestart"
      }
      driver = "docker"
      resources {
        memory = 32
      }
      config {
        image = "${consul_image}"
        entrypoint = ["/bin/sh"]
        args = ["-c", "jq </local/service.json -e '.[].Status|select(. == \"passing\")'"]
        volumes = ["tmp/service.json:/local/service.json" ]
      }
      template {
        destination = "tmp/service.json"
        data = <<EOH
          {{- service "${minio_service_name}" | toJSON -}}
        EOH
      }
    }

    # TODO: Add task waitfor-postgres (?)

    task "server" {
      driver = "docker"

%{ if use_vault_provider }
      vault {
        policies = ${vault_policy_array}
      }
%{ endif }

%{ if local_docker_image }
      artifact {
        source = "s3::http://127.0.0.1:9000/dev/tmp/docker_image.tar"
        options {
          aws_access_key_id     = "minioadmin"
          aws_access_key_secret = "minioadmin"
        }
      }
      config {
        load = "docker_image.tar"
        image = "docker_image:local"
%{ else }
      config {
        image = "${docker_image}"
%{ endif }
        volumes = [
          "local/trino/config.properties:/etc/trino/config.properties",
          "local/trino/catalog/hive.properties:/etc/trino/catalog/hive.properties",
          # Trino extra config volume destination
          "local/trino/catalog/postgresql.properties:/etc/trino/catalog/postgresql.properties",
          # JVM settings. Memory GC etc.
          "local/trino/jvm.config:/etc/trino/jvm.config",
          # Mount for debug purposes
          %{ if debug }"local/trino/log.properties:/etc/trino/log.properties",%{ endif }
        ]
      }
      template {
        destination = "secrets/.env"
        env         = true
        data = <<EOH
%{ if minio_use_vault_provider }
{{ with secret "${minio_vault_kv_path}" }}
MINIO_ACCESS_KEY="{{ .Data.data.${minio_vault_kv_access_key_name} }}"
MINIO_SECRET_KEY="{{ .Data.data.${minio_vault_kv_secret_key_name} }}"
{{ end }}
%{ else }
MINIO_ACCESS_KEY="${minio_access_key}"
MINIO_SECRET_KEY="${minio_secret_key}"
%{ endif }
EOH
      }
      // NB! If credentials set as env variable, during spin up of this container it could be sort of race condition and query `SELECT * FROM hive.default.iris;`
      //     could end up with exception: The AWS Access Key Id you provided does not exist in our records.
      //     Looks like, slow render of env variables (when one template depends on other template). Maybe because, all runs on local machine
      template {
        destination = "local/trino/catalog/hive.properties"
        data = <<EOH
connector.name=hive-hadoop2
hive.metastore.uri=thrift://{{ env "NOMAD_UPSTREAM_ADDR_${hivemetastore_service_name}" }}
hive.metastore-timeout=1m
%{ if minio_use_vault_provider }
{{ with secret "${minio_vault_kv_path}" }}
hive.s3.aws-access-key={{- .Data.data.${minio_vault_kv_access_key_name} }}
hive.s3.aws-secret-key={{- .Data.data.${minio_vault_kv_secret_key_name} }}
{{ end }}
%{ else }
hive.s3.aws-access-key=${minio_access_key}
hive.s3.aws-secret-key=${minio_secret_key}
%{ endif }
hive.s3.endpoint=http://{{ env "NOMAD_UPSTREAM_ADDR_${minio_service_name}" }}
hive.s3.path-style-access=true
hive.s3.ssl.enabled=false
hive.s3.socket-timeout=15m
# Custom hive configuration properties
${hive_config_properties}
EOH
      }
      template {
        destination   = "local/trino/catalog/postgresql.properties"
        data = <<EOH
connector.name=postgresql
connection-url=jdbc:postgresql://{{ env "NOMAD_UPSTREAM_ADDR_${postgres_service_name}" }}/${postgres_database_name}
%{ if postgres_use_vault_provider }
{{ with secret "${minio_vault_kv_path}" }}
connection-user={{- .Data.data.${postgres_vault_kv_field_username} }}
connection-password={{- .Data.data.${postgres_vault_kv_field_password} }}
{{ end }}
%{ else }
connection-user=${postgres_username}
connection-password=${postgres_password}
%{ endif }
EOH
      }
      template {
        destination   = "local/trino/config.properties"
        data = <<EOH
node-scheduler.include-coordinator=true
http-server.http.port=8080
discovery-server.enabled=true
discovery.uri=http://127.0.0.1:8080
EOH
      }        # Total memory allocation is subtracted by 256MB to keep something for the OS.
      template {
        destination   = "local/trino/jvm.config"
        data = <<EOF
-server
-Xmx{{ env "NOMAD_MEMORY_LIMIT" | parseInt | subtract 256 }}M
EOF
      }
      template {
        destination   = "local/trino/log.properties"
        data = <<EOF
#
# WARNING
# ^^^^^^^
# This configuration file is for development only and should NOT be used
# in production. For example configuration, see the Trino documentation.
#

io.trinosql=DEBUG
io.airlift=DEBUG
EOF
      }
      template {
        destination = "local/data/.additional-envs"
        change_mode = "noop"
        env         = true
        data        = <<EOF
${envs}
EOF
      }
      resources {
        memory = ${memory}
      }
    }
  }
}
