<!-- markdownlint-disable MD041 -->
<p align="center">
    <h2 align="center">Terraform-nomad-presto</h2>
</p>
<p align="center">
    <a href="https://github.com/fredrikhgrelland/vagrant-hashistack-template" alt="Built on">
        <img src="https://img.shields.io/badge/Built%20from%20template-Vagrant--hashistack--template-blue?style=for-the-badge&logo=github"/>
    </a>
    <p align="center">
        <a href="https://github.com/fredrikhgrelland/vagrant-hashistack" alt="Built on">
            <img src="https://img.shields.io/badge/Powered%20by%20-Vagrant--hashistack-orange?style=for-the-badge&logo=vagrant"/>
        </a>
    </p>
</p>

---

Module contains a nomad job [./conf/nomad/presto.hcl](./conf/nomad/presto.hcl) with [presto sql server](https://github.com/prestosql/presto).

Additional information:
- [consul-connect](https://www.consul.io/docs/connect) integration
- [nomad docker driver](https://www.nomadproject.io/docs/drivers/docker.html)

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
4. [Inputs](#inputs)
5. [Outputs](#outputs)
6. [Secrets & credentials](#secrets--credentials)
7. [Examples](#examples)
8. [Contributors](#contributors)
9. [License](#license)
10. [References](#references)

## Prerequisites
Please follow [this section in original template](https://github.com/fredrikhgrelland/vagrant-hashistack-template#install-prerequisites)

## Compatibility
|Software|OSS Version|Enterprise Version|
|:---|:---|:---|
|Terraform|0.13.1 or newer||
|Consul|1.8.3 or newer|1.8.3 or newer|
|Vault|1.5.2.1 or newer|1.5.2.1 or newer|
|Nomad|0.12.3 or newer|0.12.3 or newer|

## Requirements

### Required software
See [template README's prerequisites](template_README.md#install-prerequisites).

All software is provided and run with docker.
See the [Makefile](Makefile) for inspiration.

## Usage
The following command will run the example in [example/presto_cluster](./example/presto_cluster):
```text
make up
```
and
```text
make up-standalone
```
will run the example in [example/presto_standalone](./example/presto_standalone)

For more information, check out the documentation in the [presto_cluster](./example/presto_cluster) README.

### Connect to the services (proxies)
Since the services in this module use the [`sidecar_service`](https://www.nomadproject.io/docs/job-specification/sidecar_service), you need to connect to the services using a [consul connect proxy](https://www.consul.io/commands/connect/proxy).
The proxy connections are pre-made and defined in the `Makefile`:
```sh
make proxy-hive     # to hivemetastore
make proxy-minio    # to minio
make proxy-postgres # to postgres
make proxy-presto   # to presto
```

You can now connect to Presto using the Presto CLI with the following command:
```sh
make presto-cli # connect to Presto CLI
```

#### :warning: Note
If you are on a Mac the proxies and Presto CLI may not work.
Instead, you can install the [Consul binary](https://www.consul.io/docs/install) and run the commands in the `Makefile` manually (without `docker run ..`).
Further, you need to install the [Presto CLI](https://prestosql.io/docs/current/installation/cli.html) on your local machine or inside the box.

### Verifying setup
You can verify successful run with next steps:

#### Option 1 [hive-metastore and nomad]
* Go to [http://localhost:4646/ui/exec/hive-metastore](http://localhost:4646/ui/exec/hive-metastore)
* Chose metastoreserver -> metastoreserver and click enter.
* Connect using beeline cli
```text
# from metastore (loopback)
beeline -u jdbc:hive2://
```
* Query existing tables (beeline-cli)

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

#### Option 2 [presto and nomad]
* Go to [http://localhost:4646/ui/exec/presto](http://localhost:4646/ui/exec/presto)
* Chose standalone -> server and click enter.
* Connect using presto-cli
```text
presto
```
* Query existing tables (presto-cli)
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

#### Option 3 [local presto-cli]
`NB!` Check [required software section](#required-software) first.

* in a terminal run a proxy and `presto-cli` session
```text
make presto-cli
```

* Query tables (3 tables should be available)
```text
show tables;
select * from <table>;
```

To debug or continue developing you can use [presto cli](https://prestosql.io/docs/current/installation/cli.html) locally.
Some useful commands.
```text
# manual table creation for different file types
presto --server localhost:8080 --catalog hive --schema default --user presto --file ./example/resources/query/csv_create_table.sql
presto --server localhost:8080 --catalog hive --schema default --user presto --file ./example/resources/query/json_create_table.sql
presto --server localhost:8080 --catalog hive --schema default --user presto --file ./example/resources/query/flattenedjson_json.sql
presto --server localhost:8080 --catalog hive --schema default --user presto --file ./example/resources/query/avro_tweets_create_table.sql
```

### Providers
This module uses the [Nomad](https://registry.terraform.io/providers/hashicorp/nomad/latest/docs) provider.

### Intentions
The following intentions are required. In the examples, intentions are created in the Ansible playboook [01_create_intetion.yml](dev/ansible/01_create_intention.yml):

| Intention between | type |
| :---------------- | :--- |
| presto-local => presto | allow |
| minio-local => minio | allow |
| presto => hive-metastore | allow |
| presto-sidecar-proxy => hive-metastore | allow |
| presto-sidecar-proxy => minio | allow |

> :warning: Note that these intentions needs to be created if you are using the module in another module.

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| nomad_provider_address | Nomad provider address | string | "http://127.0.0.1:4646" | yes |
| nomad_data_center | Nomad data centers | list(string) | ["dc1"] | yes |
| nomad_namespace | [Enterprise] Nomad namespace | string | "default" | yes |
| nomad_job_name | Nomad job name | string | "presto" | yes |
| mode | Switch for nomad jobs to use cluster or standalone deployment | string | "standalone" | no |
| shared_secret_provider | Provider for the shared secret: user or Vault | string | "user" | no |
| shared_secret_user | Shared secret provided by user(length must be >= 12)  | string | "asdasdsadafdsa" | no |
| vault_secret | Set of properties to be able fetch shared cluster secret from vault  | object(bool, string, string, string) | use_vault_secret_provider = true <br> vault_kv_policy_name = "kv-secret" <br> vault_kv_path = "secret/data/presto" <br> vault_kv_secret_key_name = "cluster_shared_secret" | no |
| service_name | Presto service name | string | "presto" | yes |
| memory | Memory allocation for presto nodes | number | 1024 | no |
| cpu | CPU allocation for presto nodes | number | 500 | no |
| port | Presto http port | number | 8080 | yes |
| docker_image | Presto docker image | string | "prestosql/presto:341" | yes |
| local_docker_image | Switch for nomad jobs to use artifact for image lookup | bool | false | no |
| container_environment_variables | Presto environment variables | list(string) | [""] | no |
| workers | cluster: Number of nomad worker nodes | number | 1 | no |
| coordinator | Include a coordinator in addition to the workers. Set this to `false` when extending an existing cluster | bool | true | no |
| use_canary | Uses canary deployment for Presto | bool | false | no |
| consul_http_addr | Address to consul, resolvable from the container. e.g. <http://127.0.0.1:8500> | string | - | yes |
| consul_connect_plugin | Deploy consul connect plugin for presto | bool | true | no |
| consul_connect_plugin_version | Version of the consul connect plugin for presto (on maven central) src here: <https://github.com/gugalnikov/presto-consul-connect> | string | "2.2.0" | no |
| consul_connect_plugin_artifact_source | Artifact URI source | string | "https://oss.sonatype.org/service/local/repositories/releases/content/io/github/gugalnikov/presto-consul-connect" | no |
| debug | Turn on debug logging in presto nodes | bool | false | no |
| hivemetastore.service_name | Hive metastore service name | string | "hive-metastore" | yes |
| hivemetastore.port | Hive metastore port | number | 9083 | yes |
| minio.service_name | minio service name | string |  | yes |
| minio.port | minio port | number |  | yes |
| minio.access_key | minio access key | string |  | yes |
| minio.secret_key | minio secret key | string |  | yes |

## Outputs
| Name | Description | Type |
|------|-------------|------|
| presto_service_name | Presto service name | string |

## Secrets & credentials
When using the `mode = "cluster"`, you can set your secrets in two ways, either manually or upload secrets to Vault.

### Set credentials manually
To set the credentials manually you first need to tell the module to not fetch credentials from Vault. To do that, set `vault_secret.use_vault_secret_provider` to `false` (see below for example).
If this is done the module will use the variable `shared_secret_user` to set the Presto credentials. These will default to `defaultprestosecret` if not set by the user.
Below is an example on how to disable the use of Vault credentials, and setting your own credentials.

```hcl
module "postgres" {
...
  vault_secret  = {
                    use_vault_secret_provider = false,
                    vault_kv_policy_name      = "",
                    vault_kv_path             = "",
                    vault_kv_secret_key_name  = "",
                  }
  shared_secret_user = "my-secret-key" # default 'defaultprestosecret'
}
```

### Set credentials using Vault secrets
By default `use_vault_secret_provider` is set to `true`.
However, when testing using the box (e.g. `make dev`) the Presto secret is randomly generated and put in `secret/presto` inside Vault, from the [01_generate_secrets_vault.yml](dev/ansible/00_generate_secrets_vault.yml) playbook.
This is an independet process and will run regardless of the `vault_secret.use_vault_secret_provider` is `false/true`.

If you want to use the automatically generated credentials in the box, you can do so by changing the `vault_secret` object as seen below:
```hcl
module "postgres" {
...
  vault_secret  = {
                    use_vault_secret_provider = true
                    vault_kv_policy_name      = "kv-secret"
                    vault_kv_path             = "secret/data/presto"
                    vault_kv_secret_key_name  = "cluster_shared_secret"
                  }
}
```

If you want to change the secrets path and keys/values in Vault with your own configuration you would need to change the variables in the `vault_secret`-object.
Say that you have put your secrets in `secret/services/postgres/users` and change the key to `my_presto_secret_name`. Then you need to do the following configuration:
```hcl
module "postgres" {
...
  vault_secret  = {
                    use_vault_secret_provider = true,
                    vault_kv_policy_name     = "kv-users-secret"
                    vault_kv_path            = "secret/data/services/presto/users",
                    vault_kv_secret_key_name = "my_presto_secret_name"
                  }
}
```

## Examples
```hcl
module "presto" {
  depends_on = [
    module.minio,
    module.hive
  ]

  source = "github.com/fredrikhgrelland/terraform-nomad-presto.git?ref=0.0.1"

  nomad_job_name    = "presto"
  nomad_datacenters = ["dc1"]
  nomad_namespace   = "default"

  vault_secret = {
    use_vault_secret_provider = true
    vault_kv_policy_name      = "kv-secret"
    vault_kv_path             = "secret/data/presto"
    vault_kv_secret_key_name  = "cluster_shared_secret"
  }

  service_name = "presto"
  port         = 8080
  docker_image = "prestosql/presto:341"
  mode             = "cluster"
  workers          = 1
  consul_http_addr = "http://10.0.3.10:8500"
  debug            = true
  use_canary       = true

  minio            = local.minio
  hivemetastore    = local.hivemetastore

  memory  = 2048
  cpu     = 600

  #hivemetastore
  hivemetastore = {
    service_name = module.hive.service_name
    port         = 9083
  }

  # minio
  minio = {
    service_name = module.minio.minio_service_name
    port         = 9000
    access_key   = module.minio.minio_access_key
    secret_key   = module.minio.minio_secret_key
  }
}
```

For detailed information check [example/presto_cluster](./example/presto_cluster) directory.

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
- [Blog post](https://towardsdatascience.com/load-and-query-csv-file-in-s3-with-presto-b0d50bc773c9)
- Presto, so far (release 340), [supports only varchar columns](https://github.com/prestosql/presto/pull/920#issuecomment-517593414)
