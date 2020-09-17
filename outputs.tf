output "presto_service_name" {
  description = "Presto service name"
  value       = data.template_file.template-nomad-job-presto.vars.service_name
}