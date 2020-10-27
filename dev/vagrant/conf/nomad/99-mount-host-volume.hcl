client {
  host_volume "persistence-minio" {
    path = "/persistence/minio"
    read_only = false
  }
  host_volume "persistence-postgres" {
    path = "/persistence/postgres"
    read_only = false
  }
}