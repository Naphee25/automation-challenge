# Specifying the Microsoft Azure Provider Source and Version used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.42.0"
    }
  }
#   backend "azurerm" {
#    resource_group_name  = "resource_group"
#    storage_account_name = "cgiautomationchallenge"
#    container_name       = "tfstate"
#    key                  = "terraform.tfstate"
#  }
}


# Microsoft Azure provider configuration
provider "azurerm" {
  features {
    resource_group {
      # prevent_deletion_if_contains_resources = false
    }
  }
}

#Resource Group configuration
resource "azurerm_resource_group" "resource_group" {
    name = "${var.name}"
    location = "${var.location1}"
}

#Virtual network creation
resource "azurerm_virtual_network" "network" {
  name = "${var.name}-network"
  address_space = ["10.0.0.0/24"]
  resource_group_name = azurerm_resource_group.resource_group.name
  location = azurerm_resource_group.resource_group.location
  
}
# Define subnet
resource "azurerm_subnet" "subnet" {
  name = "${var.name}-subnet"
  address_prefixes = ["10.0.0.0/24"]
  resource_group_name = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.network.name
}

# Assign public IP address
resource "azurerm_public_ip" "public_ip" {
  name = "${var.name}-public-ip"
  location = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method = "Static"
  domain_name_label = "cgiautomateterraform"
}

# Assign network interface
resource "azurerm_network_interface" "network_interface" {
  name = "${var.name}-network-interface"
  location = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  # Configure the IP address
  ip_configuration {
    name = "${var.name}-ip-config"
    subnet_id = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}



# Configure Azure Network Security Group.
resource "azurerm_network_security_group" "network_security_group" {
  name = "${var.name}-nsg"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = azurerm_resource_group.resource_group.location

  # This block creates a security rule for incoming SSH traffic.
  security_rule {
    name = "SSH"
    priority = 300
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "22"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  # This block creates a security rule for incoming HTTP traffic.
  security_rule {
    name = "HTTP"
    priority = 320
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

  # This block creates a security rule for incoming HTTPS traffic.
  security_rule {
    name = "HTTPS"
    priority = 340
    direction = "Inbound"
    access = "Allow"
    protocol = "Tcp"
    source_port_range = "*"
    destination_port_range = "443"
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }

}

# Associates a network security group with a network interface.
resource "azurerm_network_interface_security_group_association" "network_interface_security_group" {
  network_interface_id = azurerm_network_interface.network_interface.id
  network_security_group_id = azurerm_network_security_group.network_security_group.id
}

# Generate an RSA private key for use with SSH.
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#Save the RSA private key as a local file.
resource "local_file" "private_key_file" {
  filename = "id_rsa"
  content = tls_private_key.ssh_key.private_key_pem
  file_permission = 0600
}

resource "azurerm_storage_account" "storage_account" {
    name = "cgiautomateterraform"
    resource_group_name = azurerm_resource_group.resource_group.name
    location = "${var.location1}"
    account_tier = "Standard"
    account_replication_type = "LRS"
  
}

resource "azurerm_storage_container" "storage_container" {
    name = "tfstate"
    storage_account_name = azurerm_storage_account.storage_account.name
    container_access_type = "private"
  
}

#Configure the vm 
resource "azurerm_virtual_machine" "vm" {
  name = "${var.name}-vm"
  location = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  network_interface_ids = [azurerm_network_interface.network_interface.id]
  vm_size = "Standard_B1s"

  storage_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "18.04-LTS"
    version = "latest"
  }

  storage_os_disk {
    name = "${var.name}-os-disk"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name = "${var.name}-vm"
    admin_username = "azureuser"
    admin_password = "Nafitest2!"
  }

  os_profile_linux_config {
    ssh_keys {
      # username = "azureuser"
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data  = tls_private_key.ssh_key.public_key_openssh
     }
    disable_password_authentication = true 
  }

  provisioner "file" {
    connection {
        type = "ssh"
        user = "azureuser"
        password = "Nafitest2!"
        host = azurerm_public_ip.public_ip.ip_address
    }

    source = "script/init.sh"
    destination = "/home/azureuser/init.sh"

    }
}

resource "azurerm_virtual_machine_extension" "vmext" {
  name                 = "${var.name}-vmext"
  virtual_machine_id   = azurerm_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  protected_settings = <<PROT
 {
    "script" : "${base64encode(file(var.scfile))}"
 }
PROT


  tags = {
    environment = "Production"
  }
}

# resource "null_resource" "run_commands" {
#     provisioner "remote_exec" {
#     connection {
#         type = "ssh"
#         user = "azureuser"
#         password = "Nafitest2!"
#         host = azurerm_public_ip.public_ip.ip_address
#     }

#     inline = [
#         "ls -a",
#         "sudo chmod +x init.sh",
#         "sudo ./init.sh"
#     ]

#     }
# }

