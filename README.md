<!-- markdownlint-disable MD041 -->
<p align="center">
    <h2 align="center">Terraform-nomad-trino</h2>
</p>
<p align="center">
    <a href="https://github.com/skatteetaten/vagrant-hashistack-template" alt="Built on">
        <img src="https://img.shields.io/badge/Built%20from%20template-Vagrant--hashistack--template-blue?style=for-the-badge&logo=github"/>
    </a>
    <p align="center">
        <a href="https://github.com/skatteetaten/vagrant-hashistack" alt="Built on">
            <img src="https://img.shields.io/badge/Powered%20by%20-Vagrant--hashistack-orange?style=for-the-badge&logo=vagrant"/>
        </a>
    </p>
</p>

---

Module contains a Nomad job [./conf/nomad/trino.hcl](./conf/nomad/trino.hcl) with [Trino sql server](https://github.com/trinosql/trino).

## Contents
0. [Prerequisites](#prerequisites)
1. [Compatibility](#compatibility)
2. [Requirements](#requirements)
    1. [Required software](#required-software)
3. [Usage](#usage)
    1. [Connect to the services (proxies)](#connect-to-the-services-proxies)
    2. [Verifying setup](#verifying-setup)
    3. [Providers](#providers)
    4. [Intentions](#intentions)
4. [Example usage](#example-usage)
5. [Inputs](#inputs)
6. [Outputs](#outputs)
7. [Secrets & credentials](#secrets--credentials)
8. [Contributors](#contributors)
9. [License](#license)
10. [References](#references)

## Prerequisites
Please follow [this section in original template](https://github.com/skatteetaten/vagrant-hashistack-template#install-prerequisites)

## Compatibility
|Software|OSS Version|Enterprise Version|
|:---|:---|:---|
|Terraform|0.13.1 or newer||
|Consul|1.8.3 or newer|1.8.3 or newer|
|Vault|1.5.2.1 or newer|1.5.2.1 or newer|
|Nomad|0.12.3 or newer|0.12.3 or newer|

## Requirements

### Required modules
| Module | Version |
| :----- | :------ |
| [terraform-nomad-hive](https://github.com/skatteetaten/terraform-nomad-hive) | 0.3.0 or newer |
| [terraform-nomad-minio](https://github.com/skatteetaten/terraform-nomad-minio) | 0.3.0 or newer |
| [terraform-nomad-postgres](https://github.com/skatteetaten/terraform-nomad-postgres) | 0.3.0 or newer |

### Required software
All software is provided and run with docker.
See the [Makefile](Makefile) for inspiration.

If you are using another system such as MacOS, you may need to install the following tools in some sections:
- [GNU make](https://man7.org/linux/man-pages/man1/make.1.html)
- [Docker](https://www.docker.com/)
- [Consul](https://releases.hashicorp.com/consul/)
- [Trino CLI](https://trinosql.io/docs/current/installation/cli.html)

## Usage
The following command will run the example in [example/trino_cluster](./example/trino_cluster):
```text
make up
```
and
```text
make up-standalone
```
will run the example in [example/trino_standalone](./example/trino_standalone)

For more information, check out the documentation in the [trino_cluster](./example/trino_cluster) README.

### Connect to the services (proxies)
Since the services in this module use the [`sidecar_service`](https://www.nomadproject.io/docs/job-specification/sidecar_service), you need to connect to the services using a Consul [connect proxy](https://www.consul.io/commands/connect/proxy).
The proxy connections are pre-made and defined in the `Makefile`:
```sh
make proxy-hive     # to hivemetastore
make proxy-minio    # to minio
make proxy-postgres # to postgres
make proxy-trino   # to trino
```

You can now connect to Trino using the Trino CLI with the following command:
```sh
make trino-cli # connect to Trino CLI
```

#### :warning: Note
If you are on a Mac the proxies and `make trino-cli` may not work.
Instead, you can install the [Consul binary](https://www.consul.io/docs/install) and run the commands in the `Makefile` manually (without `docker run ..`).
Further, you need to install the [Trino CLI](https://trinosql.io/docs/current/installation/cli.html) on your local machine or inside the box.
See also [required software](#required-software).

### Verifying setup
- If you ran the [trino_standalone](example/trino_standalone) example, you can verify successful deployment with either of the following options.
- If you ran the [trino_cluster](example/trino_cluster) example, you can only verify with [option 1](#option-1-hive-metastore-and-nomad) and [option 3](#option-3-local-trino-cli).

#### Option 1 [Hive-metastore and Nomad]
1. Go to [http://localhost:4646/ui/exec/hive-metastore](http://localhost:4646/ui/exec/hive-metastore)
2. Chose metastoreserver -> metastoreserver and click enter.
3. Connect using beeline cli:
```text
# from metastore (loopback)
beeline -u jdbc:hive2://
```
4. You can now query existing tables with the (beeline-cli)

```text
SHOW DATABASES;
SHOW TABLES IN <database-name>;
DROP DATABASE <database-name>;
SELECT * FROM <table_name>;

# examples
SHOW TABLES;
SELECT * FROM iris;
SELECT * FROM tweets;
```

#### Option 2 [Trino and Nomad]
> :warning: Only works with [trino_standalone](example/trino_standalone) example.

1. Go to [http://localhost:4646/ui/exec/trino](http://localhost:4646/ui/exec/trino)
2. Chose standalone -> server and click enter.
3. Connect using the Trino-cli:
```text
trino
```
4. You can now query existing tables with the Trino-cli:
```text
SHOW CATALOGS [ LIKE pattern ]
SHOW SCHEMAS [ FROM catalog ] [ LIKE pattern ]
SHOW TABLES [ FROM schema ] [ LIKE pattern ]

# examples
SHOW CATALOGS;
SHOW SCHEMAS IN hive;
SHOW TABLES IN hive.default;
SELECT * FROM hive.default.iris;
```

#### Option 3 [local Trino-cli]
> :information_source: Check [required software section](#required-software) first.

The following command contains two docker containers with the flag `--network=host`, natively run on Linux.
An important note is that MacOS Docker runs in a virtual machine. In that case, you need to use the local binary `consul` to install proxy and in another terminal local binary with `trino` cli to connect.

In a terminal run a proxy and `Trino-cli` session:
```text
make trino-cli
```

You can now query tables (3 tables should be available):
```text
show tables;
select * from <table>;
```

To debug or continue developing you can use [Trino cli](https://trinosql.io/docs/current/installation/cli.html) locally.
Some useful commands.
```text
# manual table creation for different file types
trino --server localhost:8080 --catalog hive --schema default --user trino --file ./example/resources/query/csv_create_table.sql
trino --server localhost:8080 --catalog hive --schema default --user trino --file ./example/resources/query/json_create_table.sql
trino --server localhost:8080 --catalog hive --schema default --user trino --file ./example/resources/query/flattenedjson_json.sql
trino --server localhost:8080 --catalog hive --schema default --user trino --file ./example/resources/query/avro_tweets_create_table.sql
```

### Providers
This module uses the following providers:
- [Nomad](https://registry.terraform.io/providers/hashicorp/nomad/latest/docs)
- [Vault](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)

### Intentions
The following intentions are required. In the examples, intentions are created in the Ansible playboook [01_create_intetion.yml](dev/ansible/01_create_intention.yml):

| Intention between | type |
| :---------------- | :--- |
| trino-local => trino | allow |
| minio-local => minio | allow |
| trino => hive-metastore | allow |
| trino-sidecar-proxy => hive-metastore | allow |
| trino-sidecar-proxy => minio | allow |

> :warning: Note that these intentions needs to be created if you are using the module in another module.

## Example usage
The following code is an example of the Trino module in `cluster` mode.
For detailed information check the [example/trino_cluster](example/trino_cluster) or the [example/trino_standalone](example/trino_standalone) directory.

The following code is an example usage of the [example/trino_standalone](example/trino_standalone).  
**Note: The Postgres used in this example is the same for both Hive and Trino.**
```hcl
module "trino" {
  source = "github.com/fredrikhgrelland/terraform-nomad-trino.git?ref=0.3.0"

  depends_on = [
    module.postgres,
    module.minio,
    module.hive
  ]

  # nomad
  nomad_job_name    = "trino"
  nomad_datacenters = ["dc1"]
  nomad_namespace   = "default"

  # Vault provided credentials
  vault_secret = {
    use_vault_provider         = true
    vault_kv_policy_name       = "kv-secret"
    vault_kv_path              = "secret/data/dev/trino"
    vault_kv_field_secret_name = "cluster_shared_secret"
  }

  service_name     = "trino"
  mode             = "cluster"
  workers          = 1
  consul_http_addr = "http://10.0.3.10:8500"
  debug            = true
  use_canary       = true
  hive_config_properties = [
      "hive.allow-drop-table=true",
      "hive.allow-rename-table=true",
      "hive.allow-add-column=true",
      "hive.allow-drop-column=true",
      "hive.allow-rename-column=true",
    "hive.compression-codec=ZSTD"]

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
    use_vault_provider       = true
    vault_kv_policy_name     = "kv-secret"
    vault_kv_path            = "secret/data/dev/minio"
    vault_kv_field_access_name = "access_key"
    vault_kv_field_secret_name = "secret_key"
  }

   postgres_service = {
      service_name  = module.postgres.service_name
      port          = module.postgres.port
      username      = module.postgres.username
      password      = module.postgres.password
      database_name = module.postgres.database_name
   }
   postgres_vault_secret = {
      use_vault_provider      = false
      vault_kv_policy_name    = ""
      vault_kv_path           = ""
      vault_kv_field_username = ""
      vault_kv_field_password = ""
   }
}
```

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| nomad_provider_address | Nomad provider address | string | "http://127.0.0.1:4646" | yes |
| nomad_data_center | Nomad data centers | list(string) | ["dc1"] | yes |
| nomad_namespace | [Enterprise] Nomad namespace | string | "default" | yes |
| nomad_job_name | Nomad job name | string | "trino" | yes |
| mode | Switch for Nomad jobs to use cluster or standalone deployment | string | "standalone" | no |
| shared_secret_user | Shared secret provided by user(length must be >= 12)  | string | "asdasdsadafdsa" | no |
| vault_secret | Set of properties to be able fetch shared cluster secret from Vault  | object(bool, string, string, string) | use_vault_secret_provider = true <br> vault_kv_policy_name = "kv-secret" <br> vault_kv_path = "secret/data/dev/trino" <br> vault_kv_field_secret_name = "cluster_shared_secret" | no |
| service_name | Trino service name | string | "trino" | yes |
| resource | Resource allocation for Trino nodes (cpu & memory) | object(number, number) | { <br> cpu = 500 <br> memory = 1024 <br> } | no |
| resource_proxy | Resource allocation for proxy (cpu & memory) | object(number, number) | { <br> cpu = 200 <br> memory = 128 <br> } | no |
| port | Trino http port | number | 8080 | yes |
| docker_image | Trino docker image | string | "trinodb/trino:354" | yes |
| local_docker_image | Switch for Nomad jobs to use artifact for image lookup | bool | false | no |
| container_environment_variables | Trino environment variables | list(string) | [""] | no |
| hive_config_properties | Custom hive configuration properties | list(string) | [""] | no |
| workers | cluster: Number of Nomad worker nodes | number | 1 | no |
| coordinator | Include a coordinator in addition to the workers. Set this to `false` when extending an existing cluster | bool | true | no |
| use_canary | Uses canary deployment for Trino | bool | false | no |
| consul_connect_plugin | Deploy Consul connect plugin for trino | bool | true | no |
| consul_connect_plugin_version | Version of the Consul connect plugin for trino (on maven central) src here: <https://github.com/gugalnikov/trino-consul-connect> | string | "2.2.0" | no |
| consul_connect_plugin_artifact_source | Artifact URI source | string | "https://oss.sonatype.org/service/local/repositories/releases/content/io/github/gugalnikov/trino-consul-connect" | no |
| debug | Turn on debug logging in trino nodes | bool | false | no |
| hivemetastore.service_name | Hive metastore service name | string | "hive-metastore" | yes |
| hivemetastore.port | Hive metastore port | number | 9083 | yes |
| minio_service | Minio data-object contains service_name, port, access_key and secret_key | obj(string, number, string, string) | - | no |
| minio_vault_secret | Minio data-object contains vault related information to fetch credentials | obj(bool, string, string, string, string) | { <br> use_vault_provider = false, <br> vault_kv_policy_name = "kv-secret", <br> vault_kv_path = "secret/data/dev/trino", <br> vault_kv_field_access_name = "access_key", <br> vault_kv_field_secret_name = "secret_key" <br> } | no |
| postgres_service | Postgres data-object contains service_name, port, username, password and database_name | obj(string, number, string, string, string) | - | no |
| postgres_vault_secret | Set of properties to be able to fetch Postgres secrets from vault | obj(bool, string, string, string, string) | { <br> use_vault_provider = false, <br> vault_kv_policy_name = "kv-secret", <br> vault_kv_path = "secret/data/dev/trino", <br> vault_kv_field_username = "username", <br> vault_kv_field_password = "username" <br> } | no |
| trino_memory_connector | Set of properties for a Trino memory connector | obj(bool, string) | { <br> use_memory_connector = true, <br> max_data_per_node = "128MB" <br> } | no |

## Outputs
| Name | Description | Type |
|------|-------------|------|
| trino_service_name | Trino service name | string |

## Secrets & credentials
When using the `mode = "cluster"`, you can set your secrets in two ways, either manually or upload secrets to Vault.

### Set credentials manually
To set the credentials manually you first need to tell the module to not fetch credentials from Vault. To do that, set `vault_secret.use_vault_provider` to `false` (see below for example).
If this is done the module will use the variable `shared_secret_user` to set the Trino credentials. These will default to `defaulttrinosecret` if not set by the user.
Below is an example on how to disable the use of Vault credentials, and setting your own credentials.

```hcl
module "trino" {
...
  vault_secret  = {
                    use_vault_provider         = false,
                    vault_kv_policy_name       = "",
                    vault_kv_path              = "",
                    vault_kv_field_secret_name = "",
                  }
  shared_secret_user = "my-secret-key" # default 'defaulttrinosecret'
}
```

### Set credentials using Vault secrets
By default `use_vault_provider` is set to `true`.
However, when testing using the box (e.g. `make dev`) the Trino secret is randomly generated and put in `secret/dev/trino` inside Vault, from the [01_generate_secrets_vault.yml](dev/ansible/00_generate_secrets_vault.yml) playbook.
This is an independent process and will run regardless of the `vault_secret.use_vault_provider` is `false` or `true`.

If you want to use the automatically generated credentials in the box, you can do so by changing the `vault_secret` object as seen below:
```hcl
module "trino" {
...
  vault_secret  = {
                    use_vault_secret_provider   = true
                    vault_kv_policy_name        = "kv-secret"
                    vault_kv_path               = "secret/data/dev/trino"
                    vault_kv_field_secret_name  = "cluster_shared_secret"
                  }
}
```

If you want to change the secrets path and keys/values in Vault with your own configuration you would need to change the variables in the `vault_secret`-object.
Say that you have put your secrets in `secret/services/trino/users` and change the key to `my_trino_secret_name`.
You must have Vault policy with name `kv-users-secret` and at least read-access to path `secret/services/trino/users`.
Then you need to do the following configuration:
```hcl
module "trino" {
...
  vault_secret  = {
                    use_vault_secret_provider = true,
                    vault_kv_policy_name       = "kv-users-secret"
                    vault_kv_path              = "secret/data/services/trino/users",
                    vault_kv_field_secret_name = "my_trino_secret_name"
                  }
}
```

## Contributors
[<img src="https://avatars0.githubusercontent.com/u/40291976?s=64&v=4">](https://github.com/fredrikhgrelland)
[<img src="https://avatars2.githubusercontent.com/u/29984156?s=64&v=4">](https://github.com/claesgill)
[<img src="https://avatars3.githubusercontent.com/u/15572799?s=64&v=4">](https://github.com/zhenik)
[<img src="https://avatars3.githubusercontent.com/u/67954397?s=64&v=4">](https://github.com/Neha-Sinha2305)
[<img src="https://avatars3.githubusercontent.com/u/71001093?s=64&v=4">](https://github.com/dangernil)
[<img src="https://avatars1.githubusercontent.com/u/51820995?s=64&v=4">](https://github.com/pdmthorsrud)
[<img src="https://avatars3.githubusercontent.com/u/10536149?s=64&v=4">](https://github.com/oschistad)

## License
This work is licensed under Apache 2 License. See [LICENSE](./LICENSE) for full details.

---

## References
- [Blog post](https://towardsdatascience.com/load-and-query-csv-file-in-s3-with-trino-b0d50bc773c9)
- Trino, so far (release 340), [supports only varchar columns](https://github.com/trinosql/trino/pull/920#issuecomment-517593414)
