# Presto cluster example
The current directory contains terraform related files that use the module in `../../`.
The example use of the module spins up Presto in [cluster mode](../../conf/nomad/presto.hcl) having one worker and one coordinator.
It uses Vault as the shared secret provider. For more details check [main.tf](./main.tf).

## Modules in use
| Modules       | version       |
| ------------- |:-------------:|
| [terraform-nomad-postgres](https://github.com/fredrikhgrelland/terraform-nomad-postgres) | 0.3.0 |
| [terraform-nomad-minio](https://github.com/fredrikhgrelland/terraform-nomad-minio) | 0.3.0 |
| [terraform-nomad-hive](https://github.com/fredrikhgrelland/terraform-nomad-hive) | 0.3.0 |

## Services
![img](../resources/images/terraform-nomad-presto.png)

## Example of uploaded files
This example uses the following file types found in the [example/resources/data](../resources/data) folder:
- csv
- json
- avro
- protobuf

Directory [`/resources`](../resources) contains data example with will be loaded to technology stack in the current example.

```text
├── resources
│   ├── data/           # files that are uploaded to minio
│   ├── images/         # images for documentation
│   ├── query/          # presto query example for uploaded data
│   └── schema/         # schema(s) for data serializers/deserializers
├── ...
```
