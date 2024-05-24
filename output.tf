
output "airflow_ui_url" {
  value = aws_mwaa_environment.example.webserver_url
  description = "URL of the Airflow UI"
}