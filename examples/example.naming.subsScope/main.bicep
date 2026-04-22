targetScope = 'subscription'

param environment string = 'dev'
param location string = deployment().location

/*

  NOTE: Requires Version 0.26.x or higher
  https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/user-defined-functions

*/

import { schema } from '../../naming/schema/module.bicep'
import { genName, genNameId } from '../../naming/generator/module.bicep'

// Use 'nameGenerator()'-Function for consistent naming.
output resoureGroupNamingExample string[] = [
  for index in range(0, 3): genName('Microsoft.Resources/resourceGroups', schema.default, location, {
    name: 'demo'
    environment: environment
    index: index
  })
]
