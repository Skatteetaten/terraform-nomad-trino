# Nomad

There are two Nomad jobs available.
- cluster [trino.hcl](trino.hcl)
- standalone [trino_standalone.hcl](trino_standalone.hcl)

Both must be interpolated by Terraform `template_file` and can't run without it.
