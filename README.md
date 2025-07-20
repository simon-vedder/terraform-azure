# ☁️ Terraform Modules & Projects for Microsoft Azure

This repository contains Terraform modules, templates, and complete project examples for provisioning and managing Microsoft Azure infrastructure. It serves as a personal reference and template library, showcasing real-world use cases and modular designs using Terraform best practices.

> 🧱 Built with reuse, clarity, and automation in mind.

---

## 📁 Repository Structure

```plaintext
terraform-azure/
├── modules/                 # Reusable Terraform modules (networking, storage, compute, etc.) - tbd
│   ├── network/
│   ├── storage/
│   ├── compute/
│   └── security/
├── templates/                # Example deployments using one or more modules
└── automations/              # Automations
```

## 🔧 Requirements
	•	Terraform CLI
	•	Azure CLI (az login)
	•	An active Azure subscription
	•	(Optional) Visual Studio Code with Terraform and Bicep extensions

## ✅ Features
	•	Modularized, reusable Terraform code
	•	Azure naming convention compatible
	•	Parameterized for flexibility
	•	Examples with minimal setup
	•	Automation-friendly folder structure

## 🚀 How to Use

Clone and initialize Terraform
```
git clone https://github.com/simon-vedder/terraform-azure.git
cd terraform-azure/examples/vnet-basic/
terraform init
terraform apply
```