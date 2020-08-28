locals {
  datacenters = join(",", var.nomad_datacenters)
}

data "template_file" "template-nomad-job-presto" {
  template = file("${path.module}/conf/nomad/presto.hcl")
}

resource "nomad_job" "nomad-job-presto" {
  jobspec = data.template_file.template-nomad-job-presto.rendered
  detach = false
}
