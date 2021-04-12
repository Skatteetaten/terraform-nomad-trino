# Presto standalone example
The current directory contains terraform related files that use the module in `../../`. The example module spins up Presto in [standalone mode](../conf/nomad/presto_standalone.hcl
) having one node work as both coordinator and worker.
It uses Vault as the shared secret provider. For more details check [main.tf](./main.tf).

## Modules in use
| Modules       | version       |
| ------------- |:-------------:|
| [terraform-nomad-postgres](https://github.com/skatteetaten/terraform-nomad-postgres) | 0.3.0 |
| [terraform-nomad-minio](https://github.com/skatteetaten/terraform-nomad-minio) | 0.3.0 |
| [terraform-nomad-hive](https://github.com/skatteetaten/terraform-nomad-hive) | 0.4.0 |

## Services
![img](../resources/images/terraform-nomad-presto.png)

## Example of uploaded files
This example uses the following file types found in the [example/resources/data](../resources/data) folder:
- csv
- json
- avro
- protobuf

Directory [`../resources`](../resources) contains data example with will be loaded to technology stack in the current example.

```text
├── resources
│   ├── data/           # files that are uploaded to minio
│   ├── images/         # images for documentation
│   ├── query/          # presto query example for uploaded data
│   └── schema/         # schema(s) for data serializers/deserializers
├── ...
```
