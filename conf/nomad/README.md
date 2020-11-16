# Nomad

There are two Nomad jobs available.
- cluster [presto.hcl](presto.hcl)
- standalone [presto_standalone.hcl](presto_standalone.hcl)

Both must be interpolated by terraform `template_file` and can't run without it.
