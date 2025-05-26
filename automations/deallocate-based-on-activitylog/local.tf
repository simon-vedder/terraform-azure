locals {
  subscription_id   = "<your subscription id>"
  rg_name           = "<your resource group>"
  rg_location       = "<your preferred location>"
  scope_id          = ["/subscriptions/<subscription id>"] #Activity Log Alert - the scope at which the activity log should be applied. Can be a list of ids like subscription, resource group or single resource ids. more in tf docu
}
