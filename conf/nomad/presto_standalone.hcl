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
    auto_revert       = true
    auto_promote      = true
    canary            = 1
    stagger           = "30s"
  }
  group "standalone" {
    count = 1

    network {
      mode = "bridge"
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
          }
        }
      }
      check {
        task     = "server"
        name     = "presto-hive-availability"
        type     = "script"
        command  = "presto"
        args     = ["--execute", "SHOW TABLES IN hive.default"]
        interval = "30s"
        timeout  = "15s"
      }
      check {
        expose   = true
        name     = "presto-info"
        type     = "http"
        path     = "/v1/info"
        interval = "10s"
        timeout  = "2s"
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
        image = "consul:1.8"
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
        image = "consul:1.8"
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

    task "server" {
      driver = "docker"
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
          "local/presto/config.properties:/lib/presto/default/etc/config.properties",
          "local/presto/catalog/hive.properties:/lib/presto/default/etc/catalog/hive.properties",
          # JVM settings. Memory GC etc.
          "local/presto/jvm.config:/lib/presto/default/etc/jvm.config",
          # Mount for debug purposes
          %{ if debug }"local/presto/log.properties:/lib/presto/default/etc/log.properties",%{ endif }
        ]
      }
      template {
        data = <<EOH
          MINIO_ACCESS_KEY = "${minio_access_key}"
          MINIO_SECRET_KEY = "${minio_secret_key}"
          EOH
        destination = "secrets/.env"
        env         = true
      }
      // NB! If credentials set as env variable, during spin up of this container it could be sort of race condition and query `SELECT * FROM hive.default.iris;`
      //     could end up with exception: The AWS Access Key Id you provided does not exist in our records.
      //     Looks like, slow render of env variables (when one template depends on other template). Maybe because, all runs on local machine
      template {
        destination = "/local/presto/catalog/hive.properties"
        data = <<EOH
connector.name=hive-hadoop2
hive.metastore.uri=thrift://{{ env "NOMAD_UPSTREAM_ADDR_${hivemetastore_service_name}" }}
hive.metastore-timeout=1m
hive.s3.aws-access-key=${minio_access_key}
hive.s3.aws-secret-key=${minio_secret_key}
hive.s3.endpoint=http://{{ env "NOMAD_UPSTREAM_ADDR_${minio_service_name}" }}
hive.s3.path-style-access=true
hive.s3.ssl.enabled=false
hive.s3.socket-timeout=15m
EOH
      }
      template {
        destination   = "local/presto/config.properties"
        data = <<EOH
node-scheduler.include-coordinator=true
http-server.http.port=8080
discovery-server.enabled=true
discovery.uri=http://127.0.0.1:8080
EOH
      }        # Total memory allocation is subtracted by 256MB to keep something for the OS.
      template {
        data = <<EOF
-server
-Xmx{{ env "NOMAD_MEMORY_LIMIT" | parseInt | subtract 256 }}M
EOF
        destination   = "local/presto/jvm.config"
      }
      template {
        data = <<EOF
#
# WARNING
# ^^^^^^^
# This configuration file is for development only and should NOT be used
# in production. For example configuration, see the Presto documentation.
#

io.prestosql=DEBUG
io.airlift=DEBUG

EOF
        destination   = "local/presto/log.properties"
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
