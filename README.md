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
   1. [Providers](#providers)
   2. [Intentions](#intentions)
4. [Inputs](#inputs)
5. [Outputs](#outputs)
6. [Examples](#examples)
7. [Authors](#authors)
8. [License](#license)
9. [References](#references)

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

For more information, check out the documentation in the [presto_cluster](./example/presto_cluster) README.

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
| nomad\_provider\_address | Nomad provider address | string | "http://127.0.0.1:4646" | yes |
| nomad\_data\_center | Nomad data centers | list(string) | ["dc1"] | yes |
| nomad\_namespace | [Enterprise] Nomad namespace | string | "default" | yes |
| nomad\_job\_name | Nomad job name | string | "presto" | yes |
| mode | Switch for nomad jobs to use cluster or standalone deployment | string | "standalone" | no |
| shared\_secret\_provider | Provider for the shared secret: user or vault | string | "user" | no |
| shared\_secret\_user | Shared secret provided by user(length must be >= 12)  | string | "asdasdsadafdsa" | no |
| shared\_secret\_vault | Set of properties to be able fetch shared cluster secret from vault  | object | `default = { vault_kv_policy_name = "kv-secret", vault_kv_path = "secret/data/presto", vault_kv_secret_key_name = "cluster_shared_secret"}` | no |
| memory | Memory allocation for presto nodes | number | 1024 | no |
| cpu | CPU allocation for presto nodes | number | 500 | no |
| service\_name | Presto service name | string | "presto" | yes |
| port | Presto http port | number | 8080 | yes |
| docker\_image | Presto docker image | string | "prestosql/presto:341" | yes |
| local_docker_image | Switch for nomad jobs to use artifact for image lookup | bool | false | no |
| container\_environment\_variables | Presto environment variables | list(string) | [""] | no |
| workers | cluster: Number of nomad worker nodes | number | 1 | no |
| coordinator | Include a coordinator in addition to the workers. Set this to `false` when extending an existing cluster | bool | true | no |
| use\_canary | Uses canary deployment for Presto | bool | false | no |
| consul_http_addr | Address to consul, resolvable from the container. e.g. <http://127.0.0.1:8500> | string | - | yes |
| consul\_connect\_plugin | Deploy consul connect plugin for presto | bool | true | no |
| consul_connect_plugin_version | Version of the consul connect plugin for presto (on maven central) src here: <https://github.com/gugalnikov/presto-consul-connect> | string | "2.2.0" | no |
| consul\_connect\_plugin\_artifact\_source | Artifact URI source | string | "https://oss.sonatype.org/service/local/repositories/releases/content/io/github/gugalnikov/presto-consul-connect" | no |
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
| presto\_service\_name | Presto service name | string |

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

  service_name = "presto"
  port         = 8080
  docker_image = "prestosql/presto:341"

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

## Authors

## License
This work is licensed under Apache 2 License. See [LICENSE](./LICENSE) for full details.

---

## References
- [Blog post](https://towardsdatascience.com/load-and-query-csv-file-in-s3-with-presto-b0d50bc773c9)
- Presto, so far (release 340), [supports only varchar columns](https://github.com/prestosql/presto/pull/920#issuecomment-517593414)
