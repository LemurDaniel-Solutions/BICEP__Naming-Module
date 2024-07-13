targetScope = 'resourceGroup'

param location string = resourceGroup().location
param environment string = 'dev'

/*

  NOTE: Requires Version 0.26.x or higher
  https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-functions

*/

import { defaultSchemaReference, nameGenerator } from '../modules/module.naming.bicep'

// Use 'nameGenerator()'-Function for consistent naming.
output kvNamingExample string = nameGenerator('Microsoft.KeyVault/vaults', defaultSchemaReference, {
  name: 'secrets'
  location: location
  environment: environment
})
output storageAccountNamingExample string = nameGenerator('Microsoft.Storage/storageAccounts', defaultSchemaReference, {
  name: 'objects'
  location: location
  environment: environment
})
output functionAppNamingExample string = nameGenerator('Microsoft.Web/sites/functions', defaultSchemaReference, {
  name: 'apps'
  location: location
  environment: environment
  postfixIndex: 1
})
output dataDiskNamingExample string = nameGenerator('Microsoft.Compute/disks', defaultSchemaReference, {
  name: 'apps'
  location: location
  environment: environment
  diskType: 'datadisk'
  diskLun: 1
})
output osDiskNamingExample string = nameGenerator('Microsoft.Compute/disks', defaultSchemaReference, {
  name: 'apps'
  location: location
  environment: environment
  diskType: 'osdisk'
  diskLun: 1
})
