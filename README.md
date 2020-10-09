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
2. [Usage](#usage)
   1. [Requirements](#requirements)
      1. [Required software](#required-software)
   2. [Providers](#providers)
3. [Inputs](#inputs)
4. [Outputs](#outputs)
5. [Examples](#examples)
6. [Authors](#authors)
7. [License](#license)

## Prerequisites
Please follow [this section in original template](https://github.com/fredrikhgrelland/vagrant-hashistack-template#install-prerequisites)

## Compatibility
|Software|OSS Version|Enterprise Version|
|:---|:---|:---|
|Terraform|0.13.1 or newer||
|Consul|1.8.3 or newer|1.8.3 or newer|
|Vault|1.5.2.1 or newer|1.5.2.1 or newer|
|Nomad|0.12.3 or newer|0.12.3 or newer|

## Usage

```text
make up
```

Check the example of terraform-nomad-presto documentation [here](./example).

Example contains [csv, json, avro, protobuf](./example/resources/data) file types.

### Requirements

#### Required software
See [template README's prerequisites](template_README.md#install-prerequisites).

All software is provided and run with docker.
See the [Makefile](Makefile) for inspiration.

### Providers
This module uses the [Nomad](https://registry.terraform.io/providers/hashicorp/nomad/latest/docs) provider.

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| nomad\_provider\_address | Nomad provider address | string | "http://127.0.0.1:4646" | yes |
| nomad\_data\_center | Nomad data centers | list(string) | ["dc1"] | yes |
| nomad\_namespace | [Enterprise] Nomad namespace | string | "default" | yes |
| nomad\_job\_name | Nomad job name | string | "presto" | yes |
| service\_name | Presto service name | string | "presto" | yes |
| port | Presto http port | number | 8080 | yes |
| docker\_image | Presto docker image | string | "prestosql/presto:333" | yes |
| container\_environment\_variables | Presto environment variables | list(string) | [""] | no |
| use\_canary | Uses canary deployment for Presto | bool | false | no |
| consul\_connect\_plugin | Deploy consul connect plugin for presto | bool | true | no |
| consul\_connect\_plugin\_artifact\_source | Artifact URI source | string | "https://oss.sonatype.org/service/local/repositories/releases/content/io/github/gugalnikov/presto-consul-connect" | no |
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
| presto\_port | Presto port | number |

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

For detailed information check [example/](./example) directory.

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
presto --server localhost:8080 --catalog hive --schema default --user presto --file ./example/resources/query/avro_tweets_create_table.sql
```

## Authors

## License
This work is licensed under Apache 2 License. See [LICENSE](./LICENSE) for full details.

---

## References
- [Blog post](https://towardsdatascience.com/load-and-query-csv-file-in-s3-with-presto-b0d50bc773c9)
- Presto, so far (release 340), [supports only varchar columns](https://github.com/prestosql/presto/pull/920#issuecomment-517593414)
