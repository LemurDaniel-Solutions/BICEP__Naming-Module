/*

  This naming schema follows mostly the pattern:

    XX-<?PREFIX>-<LOCATION>-<ENVIRONMENT>-<NAME>

  - This naming includes LOCATION, ENVIRONMENT and NAME, which are used to generate unique names for resources.
  - NAME is a static string, which is used to identify the resource. The name has to be seperate for resources of the same type.
  


*/

import { defaultAbbreviations } from 'var.abbr.bicep'
import { defaultLocations } from 'var.location.bicep'

@export()
var schemaReference = {
  abbreviations: defaultAbbreviations
  locations: defaultLocations

  enforceLowerCase: {
    default: true
    'Microsoft.ContainerRegistry/registries': true
    'Microsoft.Storage/storageAccounts': true
  }

  mappings: {
    // Will map any entry of parameter ENVIRONMENT to another value.
    // 
    // environment: {
    //   development: 'dev'
    // }
  }

  /*
    NOTE:
    - <PARAMETER>        : Key words that are replaced by parameters.
    - <?PARAMETER>       : ? Defines Optional parameters, which are omitted if not set.
    - <?PARAMETER;-{0}>  : This format is preferred so that the separator '-' is only set if the parameter is present.
    - <PARAMETER;{0:000}>: This format is preferred so that the index is always formatted with leading zeros.	
    - <PARAMETER;{0}>    : The format after the ; is a format string and follows the syntax of the Bicep format('{0}', value) function.
    -                    : Everything else is interpreted as a normal string.

    SPECIAL PARAMETERS:
    The following only applies for modules, that correctly implement the naming schema.
    - <INDEX>: should always point to the current index in an iteration. (For example with multiple subnets)
    - <KEY>: should always point to the current key in an iteration. (When iterating over objects with items())
    - <LOCATION>: should always point to the location of the resource.
    - <UNIQUE_STRING_N>: is a unique id based on the resource group name. (N can be any number between 0 and 9)
  
    !!! NOTE !!!
    UNIQUE_STRING_N is only available on resource group scope, since it uses the resource group name to generate the unique string.
    The deployment name is not used, because when dealing with deployment stacks, the deployment name changes with each execution.
    This doesn't happen with normal deployments, but the module is designed to work consistently in both cases.
  */

  // This is used to modify the index.
  // Most naming start counting at 1. rg-euwe-dev-project-01
  // All modules start  with index at 1 when providing the value.
  // If you want to start at 0, you can set this to -1.
  indexModifier: 0
  patterns: {
    // The pattern search logic 
    // - Look for a pattern with the resourceType and a specific kind.
    // - If not found, look for a pattern with the resourceType and the default kind.
    // - If not found, fall back to the default pattern.
    // - If not found, fail with an error.

    /*
      The function can be call without an id or with an id.
      - genName(<resourceType>, <schema>, <location>, <parameters>)
      - genName(<resourceType>::<kind>, <schema>, <location>, <parameters>)

      The id allows identification of a specific resource.
      - genNameId(<resourceType>, <id>, <schema>, <location>, <parameters>)
      - genNameId(<resourceType>::<kind>, <id>, <schema>, <location>, <parameters>)
    */

    /*
      The entries can be defined in the following ways:
    
      A single pattern for a resource type:
      - SINGLE:: must be prefixed for technical reasons. No way to tell strings apart from objects at bicep runtime.
      'SINGLE::Microsoft.Web/serverfarms': '<TYPE>-<PROJECT_NAME>-<LOCATION>-<INDEX;{0:000}>'

      Different patterns for multiple <id> or <kind> of a resource type:
      - MAP:: must be prefixed to differentiate for technical reasons.
      - <id> takes precedence over <kind>.
      'MAP::<resource_type>': {
        default: '<TYPE>-<PROJECT_NAME>-<LOCATION>-<INDEX;{0:000}>'
        <kind>: '<TYPE>-<PROJECT_NAME>-<LOCATION>-<INDEX;{0:000}>'
        <id>: '<TYPE>-<PROJECT_NAME>-<LOCATION>-<INDEX;{0:000}>'
      }
    */

    ////////////////////////////////////////////////
    ////////////////////////////////////////////////

    // This is the main Fallback pattern for resources.
    // - If no specific pattern is defined for a resource type, this will be used. 
    // - When deactivated, any resource type without a specific pattern will fail with an error.
    //   like this: 'No pattern found for resourceType: SINGLE::Microsoft.Web/serverfarms and kind: default'
    default: '<TYPE><?PREFIX;-{0}>-<LOCATION>-<ENVIRONMENT>-<NAME><?INDEX;-{0:00}>'

    ////////////////////////////////////////////////
    ////////////////////////////////////////////////

    'SINGLE::Microsoft.Subscription/alias': '<COMPANY>-<NAME>-<ENVIRONMENT>-subs-<IDENTIFIER;{0:0000}>'

    // 
    'SINGLE::Microsoft.KeyVault/vaults': 'kv<?PREFIX;-{0}>-<LOCATION>-<ENVIRONMENT>-<UNIQUE_STRING_5>'
    'SINGLE::Microsoft.Storage/storageAccounts': 'st<?PREFIX><LOCATION><ENVIRONMENT><NAME>'

    // Compute
    'MAP::Microsoft.Compute/disks': {
      data: '<TYPE><INDEX;{0:00}>-<NAME>-<ENVIRONMENT>'
      os: '<TYPE>-<NAME>-<ENVIRONMENT>'
    }

    // Container
    'SINGLE::Microsoft.ContainerRegistry/registries': 'acr<?PREFIX;-{0}>-<LOCATION>-<ENVIRONMENT>-<NAME>'

    // Network
    'SINGLE::Microsoft.Network/virtualNetworks/virtualNetworkPeerings': 'vnet<?PREFIX;-{0}>-<LOCATION>-<ENVIRONMENT>-<NAME>'

    // Maybe remove naming for origins and ruleset?
    'SINGLE::Microsoft.Cdn/profiles': 'afd<?PREFIX;-{0}>-<LOCATION>-<ENVIRONMENT>-<NAME>'
    'SINGLE::Microsoft.Cdn/profiles/afdEndpoints': 'fde<?PREFIX;-{0}>-<LOCATION>-<ENVIRONMENT>-<NAME>'
    'SINGLE::Microsoft.Cdn/profiles/originGroups': 'ogrp<?PREFIX;-{0}>-<LOCATION>-<ENVIRONMENT>-<NAME>'
    'SINGLE::Microsoft.Cdn/profiles/ruleSets': 'rset<?PREFIX><LOCATION><ENVIRONMENT><NAME>'
  }

  validate: {
    default: {
      INDEX: {
        range: [0, 999]
      }
    }

    // The logic checks for any type that starts with 'Microsoft.Compute/disks'
    'Microsoft.Compute/disks': {
      INDEX: {
        range: [0, 10]
      }
    }
  }
}
