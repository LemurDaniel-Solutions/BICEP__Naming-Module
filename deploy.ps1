

$resourceGroup = 'module.bicep-naming.examples'
$location = 'Westeurope'

try {
  

  New-AzResourceGroup -Name $resourceGroup -Location $location -Force -Confirm:$false

  Write-Host -ForegroundColor Yellow "Example 1"
  .\examples\example.naming.001\deploy.ps1
  
  Write-Host
  Write-Host
  Write-Host
  Read-Host -Prompt "Continue?"
  
  
  
  Write-Host -ForegroundColor Yellow "Example Errors"
  .\examples\example.naming.errors\deploy.ps1
  
  Write-Host
  Write-Host
  Write-Host
  Read-Host -Prompt "Continue?"
  
  
  
  Write-Host -ForegroundColor Yellow "Example Subscription Scope"
  .\examples\example.naming.subsScope\deploy.ps1
  
  Write-Host
  Write-Host
  Write-Host
  Read-Host -Prompt "Continue?"
}
finally {
  Remove-AzResourceGroup -Name $resourceGroup -Force -Confirm:$false
}
