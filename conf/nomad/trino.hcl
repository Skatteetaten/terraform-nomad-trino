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

%{ for node_type in jsondecode(node_types) ~}
  group "${node_type}" {
    count = "%{ if node_type == "coordinator" }1%{ else }${workers}%{ endif }"

    network {
      mode = "bridge"
      port "connect" {
        # This exposes the _same_ port number inside and outside of the bridge network.
        # Important so that trino can discover each other over the network.
        # Trino announces itself with `node.internal-address` and `port`
        to = -1
      }
    }
    service { #TODO: upstreams without registering a service?
      name = "${service_name}-sidecar-proxy"
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
        sidecar_task {
          resources {
            cpu    = "${cpu_proxy}"
            memory = "${memory_proxy}"
          }
        }
      }
    }
    service {
      name = "%{ if node_type == "coordinator" }${service_name}%{ else }${service_name}-worker%{ endif }"
      tags = [
      "$${NOMAD_PORT_connect}",
      "%{ if node_type == "coordinator" }coordinator%{ else }worker%{ endif }"
      ]
      port = "connect"
      task = "server"
      connect {
        native = true
      }
      check {
        name     = "trino-info"
        type     = "http"
        protocol = "https"
        tls_skip_verify = true
        path     = "/v1/info"
        interval = "10s"
        timeout  = "2s"
      }
      check {
        task     = "server"
        name     = "trino-started"
        type     = "script"
        command  = "/bin/sh"
        failures_before_critical = 2
        args     = ["-c", "curl -s -k https://127.0.0.1:$${NOMAD_PORT_connect}/v1/info | grep -Po '(?<=)\"starting\":false(?=,)[^,]*'"]
        interval = "5s"
        timeout  = "30s"
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
        # TODO: Create issue with hashicorp on this pattern. Is there a better way?
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
          # JVM settings. Memory GC etc.
          "local/trino/jvm.config:/lib/trino/default/etc/jvm.config",
          # General configuration file
          "local/trino/config.properties:/lib/trino/default/etc/config.properties",
          # Custom certificate authenticator configuration
          %{ if consul_connect_plugin }
          "local/trino/plugin/trino-consul-connect.jar:/usr/lib/trino/plugin/consulconnect/trino-consul-connect.jar",
          "local/trino/certificate-authenticator.properties:/lib/trino/default/etc/certificate-authenticator.properties",
          %{ endif }
          # Mount for debug purposes
          %{ if debug }"local/trino/log.properties:/lib/trino/default/etc/log.properties",%{ endif }
          # Hive connector configuration
          "local/trino/hive.properties:/lib/trino/default/etc/catalog/hive.properties",
          # Mounting /local/hosts to /etc/hosts overrides default docker mount.
          "local/hosts:/etc/hosts",
          # Mounting modified entrypoint.
          # The will start a background process to update /etc/hosts from /local/hosts on a 2 second interval
          # This is needed in order for the workers and coordinators to communicate by name
          "local/scripts/run-trino:/usr/lib/trino/bin/run-trino",
        ]
      }
%{ if consul_connect_plugin }
      artifact {
        # Download custom certificate authenticator plugin
        source = "${consul_connect_plugin_uri}"
        mode = "file"
        destination = "local/trino/plugin/trino-consul-connect.jar"
      }
%{ endif }
      template {
        data = <<EOH
connector.name=hive-hadoop2
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
hive.metastore.uri=thrift://{{ env "NOMAD_UPSTREAM_ADDR_${hivemetastore_service_name}" }}
hive.s3select-pushdown.enabled=true
hive.non-managed-table-writes-enabled=true
hive.s3.max-connections=5000
hive.s3.max-error-retries=100
hive.s3.socket-timeout=31m
hive.s3.ssl.enabled=false
hive.metastore-timeout=1m
hive.s3.path-style-access=true
# Custom hive configuration properties
${hive_config_properties}
EOH
        destination = "local/trino/hive.properties"
      }
      template {
        # TODO: Create issue with hashicorp. Is there a way to mount directly to /etc/hosts ( for continual updates )
        # This will add all hosts with service names trino-worker and trino to the hosts file
        data = <<EOF
127.0.0.1 %{ if node_type == "coordinator" }${service_name}%{ else }{{env "NOMAD_PORT_connect"}}.${service_name}-worker%{ endif } localhost
{{ range services }}
{{- if .Name | regexMatch "${service_name}"}}{{ range connect .Name }}{{.Address}} {{.Name}}
{{end}}{{end}}
{{- if .Name | regexMatch "${service_name}-worker"}}{{ range connect .Name }}{{.Address}} {{.Port}}.{{.Name}}
{{end}}{{end}}{{end}}
EOF
        destination = "local/hosts"
        perms = 666
        change_mode = "noop"
      }

      template {
        data = <<EOF
          {{- with caLeaf "%{ if node_type == "coordinator" }${service_name}%{ else }${service_name}-worker%{ endif }" }}
          {{- .PrivateKeyPEM }}
          {{- .CertPEM }}{{ end }}
          EOF
        destination = "local/trino.pem"
        change_mode = "noop" # Trino will automatically reload certs every 1 minute.
      }

      template {
        data = "{{- range caRoots }}{{ .RootCertPEM }}{{ end }}"
        destination = "local/roots.pem"
        change_mode = "noop" # Trino will automatically reload certs every 1 minute.
      }

      template {
        data = <<EOF
#!/bin/bash

set -xeuo pipefail

if [[ ! -d /usr/lib/trino/etc ]]; then
    if [[ -d /etc/trino ]]; then
        ln -s /etc/trino /usr/lib/trino/etc
    else
        ln -s /usr/lib/trino/default/etc /usr/lib/trino/etc
    fi
fi

set +e
grep -s -q 'node.id' /usr/lib/trino/etc/node.properties
NODE_ID_EXISTS=$$?
set -e

NODE_ID=""
if [[ $${NODE_ID_EXISTS} != 0 ]] ; then
    NODE_ID="-Dnode.id=$${HOSTNAME}"
fi

#Our change in order to pass hosts dynamically from nomad template
nohup sh -c "while true; do cat /local/hosts > /etc/hosts; sleep 2; done" >/dev/null 2>&1 & disown

exec /usr/lib/trino/bin/launcher run $${NODE_ID}
EOF
        destination = "local/scripts/run-trino"
        change_mode = "noop"
        perms = 555
      }
      template {
        data = <<EOF
CONSUL_HTTP_ADDR=${consul_http_addr}
CONSUL_SERVICE=%{ if node_type == "coordinator" }${service_name}%{ else }${service_name}-worker%{ endif }
EOF
        destination = "secrets/.env"
        env = true
      }
      template {
        data = <<EOF
certificate-authenticator.name=consulconnect
EOF
        destination   = "local/trino/certificate-authenticator.properties"
      }
      template {
data = <<EOF
node.id={{ env "NOMAD_ALLOC_ID" }}
node.environment={{ env "NOMAD_JOB_NAME" | replaceAll "-" "_" }}
node.internal-address=%{ if node_type == "coordinator" }${service_name}%{ else }{{env "NOMAD_PORT_connect"}}.${service_name}-worker%{ endif }

%{ if node_type == "coordinator" }
coordinator=true
node-scheduler.include-coordinator=false
discovery-server.enabled=true
discovery.uri=https://127.0.0.1:{{ env "NOMAD_PORT_connect" }}

dynamic.http-client.https.hostname-verification=false
failure-detector.http-client.https.hostname-verification=false
memoryManager.http-client.https.hostname-verification=false
scheduler.http-client.https.hostname-verification=false
workerInfo.http-client.https.hostname-verification=false
%{ else }
coordinator=false
discovery.uri=https://{{ range  $i, $s := connect "coordinator.${service_name}" }}{{ if eq $i 0 }}{{ .Address }}:{{ .Port }}{{ end }}{{ end }}
%{ endif }
discovery.http-client.https.hostname-verification=false
node-manager.http-client.https.hostname-verification=false
exchange.http-client.https.hostname-verification=false


http-server.http.enabled=false
http-server.authentication.type=CERTIFICATE
# Work behind proxy
http-server.authentication.allow-insecure-over-http=true
http-server.process-forwarded=true
http-server.https.enabled=true
http-server.https.port={{ env "NOMAD_PORT_connect" }}
http-server.https.keystore.path=/local/trino.pem
http-server.https.truststore.path=/local/roots.pem

# This is the same jks, but it will not do the consul connect authorization in intra cluster communication
internal-communication.https.required=true
%{ if use_vault_secret_provider }
{{ with secret "${vault_kv_path}" }}
internal-communication.shared-secret="{{ .Data.data.${vault_kv_secret_key_name}}}"
{{end}}
%{ else }
internal-communication.shared-secret= "${shared_secret_user}"
%{ endif }
internal-communication.https.keystore.path=/local/trino.pem
internal-communication.https.truststore.path=/local/roots.pem

query.client.timeout=5m
query.min-expire-age=30m
query.max-memory=${trino_query_max_memory}MB
EOF
        destination   = "local/trino/config.properties"
      }
      template {
        data = <<EOF
-server
-Xmx${trino_xmx_memory}M
-XX:-UseBiasedLocking
-XX:+UseG1GC
-XX:G1HeapRegionSize=32M
-XX:+ExplicitGCInvokesConcurrent
-XX:+HeapDumpOnOutOfMemoryError
-XX:+UseGCOverheadLimit
-XX:+ExitOnOutOfMemoryError
-XX:ReservedCodeCacheSize=256M
-Djdk.attach.allowAttachSelf=true
-Djdk.nio.maxCachedBufferSize=2000000
EOF
        destination   = "local/trino/jvm.config"
      }
      template {
        data = <<EOF
#
# WARNING
# ^^^^^^^
# This configuration file is for development only and should NOT be used
# in production. For example configuration, see the Trino documentation.
#

io.trinosql=DEBUG
io.airlift.discovery.client.Announcer=DEBUG
com.sun.jersey.guice.spi.container.GuiceComponentProviderFactory=DEBUG
io.trinosql.server.PluginManager=DEBUG
io.trinosql.trino.server.security=DEBUG
io.trinosql.server.security=DEBUG
io.github.gugalnikov.trinosql.plugin.consulconnect.ConsulConnectPlugin=DEBUG
io.github.gugalnikov=DEBUG
io.airlift=DEBUG

EOF
        destination   = "local/trino/log.properties"
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
        cpu = ${cpu}
      }
    }

  }
%{ endfor ~}
}
