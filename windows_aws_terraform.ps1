# Check if AWS CLI is installed
$awsCommand = Get-Command aws -ErrorAction SilentlyContinue
if ($awsCommand) {
    $awsCliVersion = & aws --version 2>&1
    Write-Host "AWS CLI is already installed. Version: $awsCliVersion"
}
else {
    # Install AWS CLI
    Write-Host "Installing AWS CLI..."
    Invoke-WebRequest "https://awscli.amazonaws.com/AWSCLIV2.msi" -OutFile "AWSCLIV2.msi"
    Start-Process -Wait -FilePath msiexec.exe -ArgumentList "/i", "AWSCLIV2.msi", "/quiet"
    Remove-Item "AWSCLIV2.msi"
}

# Check if the correct number of arguments is provided
if ($args.Length -eq 2) {
    # Set AWS access key and secret key environment variables
    $awsAccessKey = $args[0]
    $awsSecretKey = $args[1]

    $env:AWS_ACCESS_KEY_ID = $awsAccessKey
    $env:AWS_SECRET_ACCESS_KEY = $awsSecretKey
}
else {
    Write-Host "Please pass access key and secret as parameters."
    exit
}

# Check if Terraform is installed
$terraformVersion = Get-Command terraform -ErrorAction SilentlyContinue
if ($terraformVersion) {
    $terraformVersion = & terraform --version 2>&1
    Write-Host "Terraform is already installed. Version: $terraformVersion"
}
else {
    # Install Terraform
    $terraformZipPath = Join-Path $env:TEMP "terraform.zip"
    $terraformDestination = Join-Path $env:USERPROFILE "terraform"

    Write-Host "Installing Terraform..."
    Invoke-WebRequest "https://releases.hashicorp.com/terraform/0.15.4/terraform_0.15.4_windows_amd64.zip" -OutFile $terraformZipPath
    Expand-Archive -Path $terraformZipPath -DestinationPath $env:TEMP
    Move-Item -Path (Join-Path $env:TEMP "terraform.exe") -Destination $terraformDestination
    Remove-Item $terraformZipPath
}

