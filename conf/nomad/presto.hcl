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

%{ for node_type in jsondecode(node_types) ~}
  group "${node_type}" {
    count = "%{ if node_type == "coordinator" }1%{ else }${workers}%{ endif }"

    network {
      mode = "bridge"
      port "connect" {
        # This exposes the _same_ port number inside and outside of the bridge network.
        # Important so that presto can discover each other over the network.
        # Presto announces itself with `node.internal-address` and `port`
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
        name     = "presto-info"
        type     = "http"
        protocol = "https"
        tls_skip_verify = true
        path     = "/v1/info"
        interval = "10s"
        timeout  = "2s"
      }
      check {
        task     = "server"
        name     = "presto-started"
        type     = "script"
        command  = "/bin/sh"
        failures_before_critical = 2
        args     = ["-c", "curl -s -k https://127.0.0.1:$${NOMAD_PORT_connect}/v1/info | grep -Po '(?<=)\"starting\":false(?=,)[^,]*'"]
        interval = "5s"
        timeout  = "30s"
      }
    }

    task "certificate-handler" {
      lifecycle {
        hook    = "prestart"
        sidecar = true
      }
      driver = "docker"
      config {
        image = "fredrikhgrelland/alpine-jdk11-openssl:0.1.0"
        entrypoint = ["/bin/sh"]
          # This task is built to get certificate, ca and key from consul via. nomad template stanza and build a java keystore.
          # The container will run a shell and execute the following commands before waiting forever ´tail -f /dev/null´
          # 1. Create a pkcs12 ´local/presto.p12´ in openssl based on leaf key and certificate provided by the template stanza.
          # 2. Import ´local/presto.p12´ using keytool and output ´local/presto.jks´
          # 3. Import ´local/presto.jks´ using keytool, add root as CA and output ´alloc/presto.jks´
          # 4. Keep running the container `tail -f /dev/null`
          # Now we can use this ´/alloc/presto.jks´ from any task in the group(alloc)
        args = [
          "-c", "openssl pkcs12 -export -password pass:changeit -in /local/leaf.pem -inkey /local/leaf.key -certfile /local/leaf.pem -out /local/presto.p12; keytool -noprompt -importkeystore -srckeystore /local/presto.p12 -srcstoretype pkcs12 -destkeystore /local/presto.jks -deststoretype JKS -deststorepass changeit -srcstorepass changeit; keytool -noprompt -import -trustcacerts -keystore /local/presto.jks -storepass changeit -alias Root -file /local/roots.pem; keytool -noprompt -importkeystore -srckeystore /local/presto.jks -destkeystore /alloc/presto.jks -deststoretype pkcs12 -deststorepass changeit -srcstorepass changeit; tail -f /dev/null"
        ]
      }
      template {
        data = "{{with caLeaf \"%{ if node_type == "coordinator" }${service_name}%{ else }${service_name}-worker%{ endif }\" }}{{ .CertPEM }}{{ end }}"
        destination = "local/leaf.pem"
      }
      template {
        data = "{{with caLeaf \"%{ if node_type == "coordinator" }${service_name}%{ else }${service_name}-worker%{ endif }\" }}{{ .PrivateKeyPEM }}{{ end }}"
        destination = "local/leaf.key"
      }
      template {
        data = "{{ range caRoots }}{{ .RootCertPEM }}{{ end }}"
        destination = "local/roots.pem"
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
        # TODO: Create issue with hashicorp on this pattern. Is there a better way?
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
          # JVM settings. Memory GC etc.
          "local/presto/jvm.config:/lib/presto/default/etc/jvm.config",
          # General configuration file
          "local/presto/config.properties:/lib/presto/default/etc/config.properties",
          # Custom certificate authenticator configuration
          # TODO: add variable and make it optional
          "local/presto/plugin/presto-consul-connect.jar:/usr/lib/presto/plugin/consulconnect/presto-consul-connect.jar",
          "local/presto/certificate-authenticator.properties:/lib/presto/default/etc/certificate-authenticator.properties",
          # Mount for debug purposes
          %{ if debug }"local/presto/log.properties:/lib/presto/default/etc/log.properties",%{ endif }
          # Hive connector configuration
          "local/presto/hive.properties:/lib/presto/default/etc/catalog/hive.properties",
          # Mounting /local/hosts to /etc/hosts overrides default docker mount.
          "local/hosts:/etc/hosts",
          # Mounting modified entrypoint.
          # The will start a background process to update /etc/hosts from /local/hosts on a 2 second interval
          # This is needed in order for the workers and coordinators to communicate by name
          "local/scripts/run-presto:/usr/lib/presto/bin/run-presto",
        ]
      }
      artifact {
        # Download custom certificate authenticator plugin
        # TODO: add variable for this and make it optional
        source = "https://oss.sonatype.org/service/local/repositories/releases/content/io/github/gugalnikov/presto-consul-connect/${consul_connect_plugin_version}/presto-consul-connect-${consul_connect_plugin_version}-jar-with-dependencies.jar"
        mode = "file"
        destination = "local/presto/plugin/presto-consul-connect.jar"
      }
      template {
        data = <<EOH
          connector.name=hive-hadoop2
          hive.s3.aws-access-key=${minio_access_key}
          hive.s3.aws-secret-key=${minio_secret_key}
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
          EOH
        destination = "/local/presto/hive.properties"
      }
      template {
        # TODO: Create issue with hashicorp. Is there a way to mount directly to /etc/hosts ( for continual updates )
        # This will add all hosts with service names presto-worker and presto to the hosts file
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
#!/bin/bash

set -xeuo pipefail

if [[ ! -d /usr/lib/presto/etc ]]; then
    if [[ -d /etc/presto ]]; then
        ln -s /etc/presto /usr/lib/presto/etc
    else
        ln -s /usr/lib/presto/default/etc /usr/lib/presto/etc
    fi
fi

set +e
grep -s -q 'node.id' /usr/lib/presto/etc/node.properties
NODE_ID_EXISTS=$$?
set -e

NODE_ID=""
if [[ $${NODE_ID_EXISTS} != 0 ]] ; then
    NODE_ID="-Dnode.id=$${HOSTNAME}"
fi

#Our change in order to pass hosts dynamically from nomad template
nohup sh -c "while true; do cat /local/hosts > /etc/hosts; sleep 2; done" >/dev/null 2>&1 & disown

exec /usr/lib/presto/bin/launcher run $${NODE_ID}
EOF
        destination = "local/scripts/run-presto"
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
        destination   = "local/presto/certificate-authenticator.properties"
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
http-server.https.keystore.path=/alloc/presto.jks
http-server.https.keystore.key=changeit

# This is the same jks, but it will not do the consul connect authorization in intra cluster communication
internal-communication.https.required=true
internal-communication.shared-secret=${cluster_shared_secret}
internal-communication.https.keystore.path=/alloc/presto.jks
internal-communication.https.keystore.key=changeit

query.client.timeout=5m
query.min-expire-age=30m
EOF
        destination   = "local/presto/config.properties"
      }
        # Total memory allocation is subtracted by 256MB to keep something for the OS.
      template {
        data = <<EOF
-server
-Xmx{{ env "NOMAD_MEMORY_LIMIT" | parseInt | subtract 256 }}M
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
io.airlift.discovery.client.Announcer=DEBUG
com.sun.jersey.guice.spi.container.GuiceComponentProviderFactory=DEBUG
io.prestosql.server.PluginManager=DEBUG
io.prestosql.presto.server.security=DEBUG
io.prestosql.server.security=DEBUG
io.github.gugalnikov.prestosql.plugin.consulconnect.ConsulConnectPlugin=DEBUG
io.github.gugalnikov=DEBUG
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
%{ endfor ~}
}