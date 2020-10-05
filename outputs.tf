output "presto_service_name" {
  description = "Presto service name"
  value       = data.template_file.template_nomad_job_presto.vars.service_name
}