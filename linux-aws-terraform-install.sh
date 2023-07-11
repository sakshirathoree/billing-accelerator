#!/bin/bash

# Check if AWS CLI is installed
if command -v aws >/dev/null 2>&1; then
    echo "AWS CLI is already installed."
else
    # Install AWS CLI
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
fi
# Read access key and secret key from positional arguments
access_key="$1"
secret_key="$2"

#echo "Pass valid access key and secret as a parameter while running the script"

if [ $# -eq 2 ]
then
# Configure AWS CLI with provided access key and secret key
echo "Configuring AWS CLI..."
aws configure set aws_access_key_id "$access_key"
aws configure set aws_secret_access_key "$secret_key"
else
echo "please pass access key and secret as a parameter"
exit
fi

# Check if Terraform is installed
if command -v terraform >/dev/null 2>&1; then
    echo "Terraform is already installed."
else
    # Install Terraform
    echo "Installing Terraform..."
    curl "https://releases.hashicorp.com/terraform/0.15.4/terraform_0.15.4_linux_amd64.zip" -o "terraform.zip"
    unzip terraform.zip
    sudo mv terraform /usr/local/bin
fi


