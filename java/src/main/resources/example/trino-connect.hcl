job "trino-connect" {
  type = "service"
  datacenters = ["dc1"]

  group "trino" {

    count = 1

    task "certificate-handler" {
      driver = "docker"
      config {
        image = "tomcat:9.0"
        entrypoint = ["/bin/sh"]
        args = [
          "-c", "openssl pkcs12 -export -password pass:changeit -in /local/leaf.pem -inkey /local/leaf.key -certfile /local/leaf.pem -out /local/trino.p12; keytool -noprompt -importkeystore -srckeystore /local/trino.p12 -srcstoretype pkcs12 -destkeystore /local/trino.jks -deststoretype JKS -deststorepass changeit -srcstorepass changeit; keytool -noprompt -import -trustcacerts -keystore /local/trino.jks -storepass changeit -alias Root -file /local/roots.pem; keytool -noprompt -importkeystore -srckeystore /local/trino.jks -destkeystore /alloc/trino.jks -deststoretype pkcs12 -deststorepass changeit -srcstorepass changeit; tail -f /dev/null"
        ]
      }

      template {
        data = <<EOF
CONSUL_SERVICE=trino
CONSUL_HTTP_ADDR=<your consul address>
EOF
        destination = "${NOMAD_SECRETS_DIR}/.env"
        env = true
      }
      template {
        data = "{{ with printf \"%s\" (or (env \"CONSUL_SERVICE\") \"trino\") | caLeaf }}{{ .CertPEM }}{{ end }}"
        destination = "local/leaf.pem"
      }
      template {
        data = "{{ with printf \"%s\" (or (env \"CONSUL_SERVICE\") \"trino\") | caLeaf }}{{ .PrivateKeyPEM }}{{ end }}"
        destination = "local/leaf.key"
      }
      template {
        data = "{{ range caRoots }}{{ .RootCertPEM }}{{ end }}"
        destination = "local/roots.pem"
      }
    }
    task "coordinator" {
      driver = "docker"

      config {
        image = "trino/trino:latest"
        volumes = [
          "local/trino/jvm.config:/lib/trino/default/etc/jvm.config",
          "local/trino/config.properties:/lib/trino/default/etc/config.properties",
          "local/trino/certificate-authenticator.properties:/lib/trino/default/etc/certificate-authenticator.properties",
          "local/trino/log.properties:/lib/trino/default/etc/log.properties",
          "/Users/aviveros/Workspace/trino/plugin:/usr/lib/trino/plugin/consulconnect",
        ]
      }
      template {
        data = <<EOF
CONSUL_SERVICE=trino
CONSUL_HTTP_ADDR=<your consul address>
EOF
        destination = "${NOMAD_SECRETS_DIR}/.env"
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
node.internal-address=<CN of the leaf certificate>

coordinator=true
node-scheduler.include-coordinator=false
discovery-server.enabled=true
discovery.uri=https://<CN of the leaf certificate>:8088

http-server.http.enabled=false
http-server.authentication.type=CERTIFICATE
http-server.https.enabled=true
http-server.https.port=8088
http-server.https.keystore.path=/alloc/trino.jks
http-server.https.keystore.key=changeit

# This is the same jks, but it will not do the consul connect authorization in intra cluster communication
internal-communication.https.required=true
internal-communication.shared-secret=asdasdsadafdsa
internal-communication.https.keystore.path=/alloc/trino.jks
internal-communication.https.keystore.key=changeit

query.client.timeout=5m
query.min-expire-age=30m
EOF
        destination   = "local/trino/config.properties"
      }
      template {
        data = <<EOF
-server
-Xmx1768M
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

io.trino=DEBUG
com.sun.jersey.guice.spi.container.GuiceComponentProviderFactory=DEBUG
com.ning.http.client=DEBUG
io.trino.server.PluginManager=DEBUG
io.trino.trino.server.security=DEBUG
io.trino.plugin.certificate.consulconnect=DEBUG

EOF
        destination   = "local/trino/log.properties"
      }
      service {
          port = "http"
          name = "trino"
        }
        resources {
          memory = 2048
          network {
            mode = "bridge"
            port "http" {
              to     = 8088
              static = 8088
            }
          }
        }
    }
  }
}