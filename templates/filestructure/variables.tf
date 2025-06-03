// variables.tf
// defines input variables used within the configuration

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "TestProject"
}

variable "resourcegroup_name" {
  description = "Name of the resourcegroup"
  type        = string
  default     = "TestRG"
}

variable "location" {
  description = "Defines the location"
  type        = string
  default     = "westeurope"
}

variable "tags" {
  description = "Define default tags"
  type        = map(string)
}

// many many more