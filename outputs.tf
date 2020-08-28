output "presto_service_name" {
  description = "Presto service name"
  value       = data.template_file.template-nomad-job-presto.vars.service_name
}

output "presto_port" {
  description = "Presto local bind port"
  value       = data.template_file.template-nomad-job-presto.vars.port
}

