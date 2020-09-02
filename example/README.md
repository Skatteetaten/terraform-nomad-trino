# This is a Presto terraform module example

The current directory contains terraform related files that use the module in `../`. See [template_example](../template_example/example/).

## Services
![img](./terraform-nomad-presto.png)

## Example of uploaded files
Directory `/resources` contains data example with will be loaded to technology stack in the current example.

```text
├── resources
│   ├── data/           # files that are uploaded to minio
│   ├── query/          # presto query example for uploaded data
│   └── schema/         # schema(s) for data serializers/deserializers
├── ...
```

## References
- [Creating Modules - official terraform documentation](https://www.terraform.io/docs/modules/index.html)
