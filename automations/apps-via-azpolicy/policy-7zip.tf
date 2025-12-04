/*
###############################################

Polcies for installing an custom agent

Creates:
- Resource Group 
- Storage Account for Storing the Zip File (Contains Resources)
- Creates install & uninstall scripts, zip and upload them - 7zip as example
- Azure Compute Gallery & VM Application with Custom Agent
- the final Policy & Remediation to install the VM application

###############################################
*/

# uncomment this if you do not get the subscription id centrally
#data "azurerm_subscription" "current" {}

# ============================================================================
# Resource Group & Storage for Storing Installation Files
# ============================================================================
resource "azurerm_resource_group" "gallery" {
  name     = "rg-gallery-vmapps"
  location = "westeurope"
}

# Storage Account für die Installationspakete
resource "azurerm_storage_account" "vmapps" {
  name                     = "stvmapps${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.gallery.name
  location                 = azurerm_resource_group.gallery.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    purpose = "vm-applications"
  }
}

resource "azurerm_storage_container" "packages" {
  name                  = "packages"
  storage_account_id    = azurerm_storage_account.vmapps.id
  container_access_type = "private"
}

# Random Suffix für eindeutige Namen
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# ============================================================================
# Create Local PowerShell Installation-Scripts & zip it
# ============================================================================
# install.ps1 - 7-Zip Installation
resource "local_file" "install_script" {
  filename = "${path.module}/scripts/install.ps1"
  content  = <<-EOT
    # 7-Zip Installation Script
    $ErrorActionPreference = "Stop"
    
    $7zipUrl = "https://www.7-zip.org/a/7z2408-x64.exe"
    $installerPath = "$env:TEMP\7z-installer.exe"
    
    Write-Host "Downloading 7-Zip..."
    Invoke-WebRequest -Uri $7zipUrl -OutFile $installerPath
    
    Write-Host "Installing 7-Zip..."
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait -NoNewWindow
    
    Write-Host "Cleaning up..."
    Remove-Item -Path $installerPath -Force
    
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\7-Zip'
    if (Test-Path $regPath) {
      Write-Host "7-Zip installation completed successfully!"
      exit 0
    }
    else {
      Write-Output "7-Zip ist nicht installiert oder der Registry-Pfad existiert nicht."
      exit 1
    }

    
  EOT
}

# uninstall.ps1 - 7-Zip Deinstallation
resource "local_file" "uninstall_script" {
  filename = "${path.module}/scripts/uninstall.ps1"
  content  = <<-EOT
    # 7-Zip Uninstallation Script
    $ErrorActionPreference = "Stop"
    
    $uninstallerPath = "C:\Program Files\7-Zip\Uninstall.exe"
    
    if (Test-Path $uninstallerPath) {
        Write-Host "Uninstalling 7-Zip..."
        Start-Process -FilePath $uninstallerPath -ArgumentList "/S" -Wait -NoNewWindow

        $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\7-Zip'
        if (Test-Path $regPath) {
          Write-Host "7-Zip uninstallation not successful!"
          exit 1
        }
        else {
          Write-Host "7-Zip uninstalled successfully!"
          exit 0
        }
       
    } else {
        Write-Host "7-Zip is not installed or uninstaller not found."
    }
  EOT
}


data "archive_file" "app_package-pwsh" {
  type        = "zip"
  output_path = "${path.module}/7zip-package-pwsh.zip"

  source {
    content  = local_file.install_script.content
    filename = "install.ps1"
  }

  source {
    content  = local_file.uninstall_script.content
    filename = "uninstall.ps1"
  }

  depends_on = [
    local_file.install_script,
    local_file.uninstall_script
  ]
}


# Upload ZIP to Storage Account
resource "azurerm_storage_blob" "app_package-pwsh" {
  name                   = "7zip-package-pwsh-${formatdate("YYYYMMDDhhmmss", timestamp())}.zip"
  storage_account_name   = azurerm_storage_account.vmapps.name
  storage_container_name = azurerm_storage_container.packages.name
  type                   = "Block"
  source                 = data.archive_file.app_package-pwsh.output_path
}

# Generate SAS Token for Blob-Access
data "azurerm_storage_account_blob_container_sas" "package_sas-pwsh" {
  connection_string = azurerm_storage_account.vmapps.primary_connection_string
  container_name    = azurerm_storage_container.packages.name
  https_only        = true

  start  = timestamp()
  expiry = timeadd(timestamp(), "8760h") # 1 year

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = true
  }
}

# ============================================================================
# AZURE COMPUTE GALLERY
# ============================================================================
resource "azurerm_shared_image_gallery" "main" {
  name                = "gallery_vmapps_${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.gallery.name
  location            = azurerm_resource_group.gallery.location
  description         = "Compute Gallery für VM Applications"

  tags = {
    environment = "production"
    purpose     = "vm-applications"
  }
}

# ============================================================================
# VM APPLICATION DEFINITION
# ============================================================================
resource "azurerm_gallery_application" "sevenzip-pwsh" {
  name              = "7zip-pwsh"
  gallery_id        = azurerm_shared_image_gallery.main.id
  location          = azurerm_resource_group.gallery.location
  supported_os_type = "Windows"
  description       = "7-Zip File Archiver for Windows VMs"

  tags = {
    application = "7zip"
    version     = "24.08"
  }
}


# VM APPLICATION VERSION
resource "azurerm_gallery_application_version" "sevenzip_v1-pwsh" {
  name                   = "1.0.0"
  gallery_application_id = azurerm_gallery_application.sevenzip-pwsh.id
  location               = azurerm_resource_group.gallery.location

  manage_action {
    install = "powershell.exe -command \"Rename-Item -Path '.\\${azurerm_gallery_application.sevenzip-pwsh.name}' -NewName 'app.zip'; Expand-Archive -Path '.\\app.zip' -DestinationPath '.\\app'; Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force; powershell.exe -ExecutionPolicy Bypass -File '.\\app\\install.ps1';\""
    remove  = "powershell.exe -command \"Rename-Item -Path '.\\${azurerm_gallery_application.sevenzip-pwsh.name}' -NewName 'app.zip'; Expand-Archive -Path '.\\app.zip' -DestinationPath '.\\app'; Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force; powershell.exe -ExecutionPolicy Bypass -File '.\\app\\uninstall.ps1';\""
  }

  source {
    media_link = "${azurerm_storage_blob.app_package-pwsh.url}${data.azurerm_storage_account_blob_container_sas.package_sas-pwsh.sas}"
  }

  target_region {
    name                   = azurerm_resource_group.gallery.location
    regional_replica_count = 1
  }

  tags = {
    version = "1.0.0"
  }
}

# ============================================================================
# AZURE POLICY: VM APPLICATION ERZWINGEN
# ============================================================================
# Custom Policy Definition - basierend auf Microsoft ARM Template Struktur
resource "azurerm_policy_definition" "deploy_7zip" {
  name         = "deploy-7zip-on-windows-vms"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Deploy 7-Zip on Windows VMs"
  description  = "Automatically deploys 7-Zip VM Application to all Windows VMs using ARM template deployment"

  metadata = <<METADATA
    {
      "category": "Compute",
      "version": "1.0.0"
    }
METADATA

  parameters = <<PARAMETERS
    {
      "subscriptionId": {
        "type": "String",
        "metadata": {
          "displayName": "Subscription ID",
          "description": "The subscription ID where the gallery is located"
        }
      },
      "resourceGroupName": {
        "type": "String",
        "metadata": {
          "displayName": "Gallery Resource Group Name",
          "description": "The resource group name where the gallery is located"
        }
      },
      "galleryName": {
        "type": "String",
        "metadata": {
          "displayName": "Gallery Name",
          "description": "The name of the Compute Gallery"
        }
      },
      "applicationName": {
        "type": "String",
        "metadata": {
          "displayName": "Application Name",
          "description": "The name of the VM Application"
        }
      },
      "applicationVersion": {
        "type": "String",
        "defaultValue": "1.0.0",
        "metadata": {
          "displayName": "Application Version",
          "description": "The version of the VM Application to deploy"
        }
      }
    }
PARAMETERS

  policy_rule = <<POLICY_RULE
    {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Compute/virtualMachines"
          },
          {
            "field": "Microsoft.Compute/virtualMachines/storageProfile.osDisk.osType",
            "equals": "Windows"
          }
        ]
      },
      "then": {
        "effect": "deployIfNotExists",
        "details": {
          "type": "Microsoft.Compute/virtualMachines",
          "name": "[field('name')]",
          "roleDefinitionIds": [
            "/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
          ],
          "existenceCondition": {
            "allOf": [
              {
                "count": {
                  "field": "Microsoft.Compute/virtualMachines/applicationProfile.galleryApplications[*]",
                  "where": {
                    "field": "Microsoft.Compute/virtualMachines/applicationProfile.galleryApplications[*].packageReferenceId",
                    "equals": "[parameters('applicationVersion')]"
                  }
                },
                "greater": 0
              }
            ]
          },
          "deployment": {
            "properties": {
              "mode": "incremental",
              "parameters": {
                "vmName": {
                  "value": "[field('name')]"
                },
                "location": {
                  "value": "[field('location')]"
                },
                "subscriptionId": {
                  "value": "[parameters('subscriptionId')]"
                },
                "resourceGroupName": {
                  "value": "[parameters('resourceGroupName')]"
                },
                "galleryName": {
                  "value": "[parameters('galleryName')]"
                },
                "applicationName": {
                  "value": "[parameters('applicationName')]"
                },
                "applicationVersion": {
                  "value": "[parameters('applicationVersion')]"
                }
              },
              "template": {
                "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
                "contentVersion": "1.0.0.0",
                "parameters": {
                  "vmName": {
                    "type": "string"
                  },
                  "location": {
                    "type": "string"
                  },
                  "subscriptionId": {
                    "type": "string"
                  },
                  "resourceGroupName": {
                    "type": "string"
                  },
                  "galleryName": {
                    "type": "string"
                  },
                  "applicationName": {
                    "type": "string"
                  },
                  "applicationVersion": {
                    "type": "string"
                  }
                },
                "variables": {
                  "packageReferenceId": "[format('/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/galleries/{2}/applications/{3}/versions/{4}', parameters('subscriptionId'), parameters('resourceGroupName'), parameters('galleryName'), parameters('applicationName'), parameters('applicationVersion'))]"
                },
                "resources": [
                  {
                    "type": "Microsoft.Compute/virtualMachines/VMapplications",
                    "apiVersion": "2021-07-01",
                    "name": "[concat(parameters('vmName'), '/', parameters('applicationName'))]",
                    "location": "[parameters('location')]",
                    "properties": {
                      "packageReferenceId": "[variables('packageReferenceId')]"
                    }
                  }
                ]
              }
            }
          }
        }
      }
    }
POLICY_RULE
}

# Policy Assignment auf Subscription-Level
resource "azurerm_subscription_policy_assignment" "deploy_7zip" {
  name                 = "deploy-7zip-windows-vms"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = azurerm_policy_definition.deploy_7zip.id
  display_name         = "Deploy 7-Zip on all Windows VMs"
  description          = "Automatically deploys 7-Zip to all Windows VMs in the subscription"
  location             = azurerm_resource_group.gallery.location

  identity {
    type = "SystemAssigned"
  }

  parameters = jsonencode({
    subscriptionId = {
      value = data.azurerm_subscription.current.id
    }
    resourceGroupName = {
      value = azurerm_resource_group.gallery.name
    }
    galleryName = {
      value = azurerm_shared_image_gallery.main.name
    }
    applicationName = {
      value = azurerm_gallery_application.sevenzip-pwsh.name
    }
    applicationVersion = {
      value = "1.0.0"
    }
  })
}

# Role Assignment für die Policy Identity
resource "azurerm_role_assignment" "policy_vm_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_subscription_policy_assignment.deploy_7zip.identity[0].principal_id
}

resource "azurerm_subscription_policy_remediation" "this" {
  name                           = "remediate-7zip"
  subscription_id                = data.azurerm_subscription.current.id
  policy_assignment_id           = azurerm_subscription_policy_assignment.deploy_7zip.id
  policy_definition_reference_id = azurerm_subscription_policy_assignment.deploy_7zip.policy_definition_id
  resource_discovery_mode        = "ReEvaluateCompliance"

  depends_on = [
    azurerm_role_assignment.policy_vm_contributor
  ]
}