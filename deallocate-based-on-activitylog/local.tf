locals {
  subscription_id   = ""
  rg_name           = "management-automations" 
  rg_location       = "westeurope"
  scope_id          = [""] #Activity Log Alert - the scope at which the activity log should be applied. Can be a list of ids like subscription, resource group or single resource ids
}
