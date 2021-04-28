# trino-connect example

This is a very simple example to try out the plugin's functionality on a dockerized Trino.

## prerequisites

The example requires:

- a running Consul agent with connect enabled
- a running Nomad
- proper environment variables for Nomad & Consul setup (eg. CONSUL_HTTP_ADDR)

## considerations

- this is a single node example
- it doesn't enforce Consul ACLs
- requires Trino 334+
- the example uses a certificate handler as a side task which procures the necessary certificates and JKS
- the code for this task can run on any docker image which has a JDK and openssl
- the Trino image used by the Nomad job must be preloaded with the plugin's jar-with-dependencies
- if you wish to use the official image as base it will work fine, but you have to make sure to copy the jar to the right location in the container
- the Common Name (CN) in Consul's leaf certificate for Trino needs to be inspected or inferred beforehand in order to comply with hostname verification at runtime
- this issue has been reported to Consul as a feature request [https://github.com/hashicorp/consul/issues/8170](https://github.com/hashicorp/consul/issues/8170)

## running the example

- update the placeholders in trino-connect.hcl with the proper values for your own environment
- from a terminal session standing on this directory:

  - make run-nomad-job
  - make register-trino-service
  - make run-connect-proxy
  - make test-connect-proxy

- in this example, communication towards Trino will be allowed by default for any other service which is part of the mesh
- once intentions have been configured using the Consul UI, access should be allowed / denied according to such configuration