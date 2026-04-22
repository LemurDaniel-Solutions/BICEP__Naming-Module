param location string = resourceGroup().location
param environment string = 'development'

/*

  NOTE: Requires Version 0.26.x or higher
  https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-functions

*/

import { schema } from '../../naming/schema/module.bicep'
import { genName, genNameId } from '../../naming/generator/module.bicep'

// Use 'genName'-Function for consistent naming.
output kvNamingExample string = genName('Microsoft.KeyVault/vaults', schema.default, location, {
  name: 'secrets'
  environment: 'test'
})
output storageAccountNamingExample string = genName('Microsoft.Storage/storageAccounts', schema.default, location, {
  name: 'objects'
  environment: environment
})
output functionAppNamingExample string = genName('Microsoft.Web/sites::function', schema.default, location, {
  name: 'apps'
  environment: environment
  index: 1
})
output dataDiskNamingExample string = genName('Microsoft.Compute/disks::data', schema.default, location, {
  name: 'apps'
  environment: environment
  index: 1
})
output osDiskNamingExample string = genName('Microsoft.Compute/disks::os', schema.default, location, {
  name: 'apps'
  environment: environment
  index: 1
})
