


<#

# Optionally login to azure
Connect-AzAccount

# Optionally set the context the subscription
Set-AzContext -Subscription <subscrptionId>

#>

$resourceGroup = 'module.bicep-naming.examples'
$location = 'Westeurope'

New-AzResourceGroup -Name $resourceGroup -Location $location

$Deployment = @{
    Name                  = "example.naming.vnet"
    ResourceGroupName     = $resourceGroup
    TemplateFile          = "./example.naming.vnet/main.bicep"
    TemplateParameterFile = "./example.naming.vnet/environments/dev.main.bicepparam"
    DenySettingsMode      = 'None'
    DeleteResources       = $true
}
    
$deployment = New-AzResourceGroupDeploymentStack @Deployment -Verbose

$deployment

Write-Host ($Deployment.outputs | ConvertTo-Json)

# Remove-AzResourceGroupDeploymentStack -ResourceGroupName $resourceGroup -Name $resourceGroup -DeleteAll -Verbose
