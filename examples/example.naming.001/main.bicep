targetScope = 'resourceGroup'

param location string = resourceGroup().location
param environment string = 'dev'

/*

  NOTE: Requires Version 0.26.x or higher
  https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-functions

*/

import { defaultSchema } from '../../modules/naming-schema/module.bicep'
import { genName, genNameId } from '../../modules/naming/module.bicep'

// Use 'nameGenerator()'-Function for consistent naming.
output kvNamingExample string = genName('Microsoft.KeyVault/vaults', defaultSchema, location, {
  name: 'secrets'
  environment: environment
})
output storageAccountNamingExample string = genName('Microsoft.Storage/storageAccounts', defaultSchema, location, {
  name: 'objects'
  environment: environment
})
output functionAppNamingExample string = genName('Microsoft.Web/sites::function', defaultSchema, location, {
  name: 'apps'
  environment: environment
  index: 1
})
output appServiceNamingExample string = genName('Microsoft.Web/sites::app', defaultSchema, location, {
  name: 'apps'
  environment: environment
  index: 1
})
output dataDiskNamingExample string = genName('Microsoft.Compute/disks::data', defaultSchema, location, {
  name: 'apps'
  environment: environment
  index: 1
})
output osDiskNamingExample string = genName('Microsoft.Compute/disks::os', defaultSchema, location, {
  name: 'apps'
  environment: environment
  index: 1
})
