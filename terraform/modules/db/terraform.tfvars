global_prefix      = "testdb"
project_id         = "open-targets-eu-dev"
region             = "europe-west1"
zone               = "europe-west1-d"
machine_type       = "n1-standard-8"
opensearch_version = "3.1.0"
clickhouse_version = "25.8.2.29"
labels = {
  "app"         = "opensearch",
  "team"        = "open-targets",
  "subteam"     = "backend",
  "product"     = "platform",
  "tool"        = "nextgen",
  "environment" = "development",
  "created_by"  = "terraform",
}
