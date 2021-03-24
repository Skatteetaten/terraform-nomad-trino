output "trino_service_name" {
  description = "Trino service name"
  value       = data.template_file.template_nomad_job_trino.vars.service_name
}