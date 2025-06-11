// terraform.tfvars
// provides values for variables defined in variables.tf
// often used for secret information - so do not publish this file in your git repo

project_name       = "ProjectOne"
resourcegroup_name = "ProjectOne-rg"
location           = "germanywestcentral"

tags = {
  "Author"  = "Simon Vedder"
  "Contact" = "info@simonvedder.com"
}