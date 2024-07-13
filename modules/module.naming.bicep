/*


  NOTE: 
  This is just how I do it. I mean do whatever you want with it. :D

  #################################################################

  [MODULE_CALL] How to call modules, that implement this naming schema:

  if implement correctly, the should have a naming input-parameter, that can be used to provide the parameters for the naming schema.
  it can also be used, to provide a different schema, if multiple naming conventions are used.

  module container_registry '../module.bicep' = {
    name: 'container_registry'
    params: {
      // schema: null  // Optional: Provide a custom naming schema for the resource. Default is used if not provided.
      naming: {
        name: 'test123'
        environment: environment
      }
    }
  }

  #################################################################

  [MODULE_CREATION] How to Implement in modules:

  1. The module should import the nameGenerator-Function and the defaultSchemaReference.

    import { defaultSchemaReference, nameGenerator } from '../../governance/naming/module.bicep'

  2. The module should define the following inpurt-parameter:

    @description('Provide a custom naming schema for the resource. Default is used if not provided.')
    param schema object?
    @description('Define any parameters used for name generation here.')
    param naming {
      *: string
    }

  3. The module should in some way check for a specific shema and fallback to the defaultSchemaReference if not provided.

      var varDefaultSettings = {
        naming: {
          schema: defaultSchemaReference
        }
      }
      var varAppliedSettings = {
        naming: {
          parameters: naming
          schema: schema ?? varDefaultSettings.naming.schema
        }
      }
    
  4. The module should call the nameGenerator-Function with the correct parameters.

    resource resRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
      name: nameGenerator(
        'Microsoft.ContainerRegistry/registries', // The exacat resource type without the api-version
        varAppliedSettings.naming.schema, // The reference to the schema to use
        // The parameters to use for naming
        union(
          {
            // !!! NOTE !!!
            // Always provide common parameters for the calls, so that it can be used to customize the naming schema in any way.
            // - Location: most resources have a location, else set it to null
            // - Index: when iterating over arrays, provide the index, else set it to 0
            // - Key: when iterating over objects with items(), provide the key, else set it to null
            key: null
            index: 0
            location: location
          },
          // These are the parameters provided via the naming input-parameter.
          varAppliedSettings.naming.parameters
        )
      )
    } 

/*

/*

  Define a schema for naming resources.

  NOTE:
  multiple different Schemas can be created in this or other modules and later provided to the function, 
  resulting in different names to handle multiple naming conventions.
  
  nameGenerator(
    'Microsoft.KeyVault/vaults',
    // Provide different schemas for different naming conventions
    defaultSchemaReference, 
    {
      name: 'secrets'
      location: location
      environment: environment
    }
  )

*/

@export()
var defaultSchemaReference = {
  locations: {
    'West Europe': 'euwe'
    westeurope: 'euwe'

    'Germany North': 'geno'
    germanynorth: 'geno'

    'Germany West Central': 'gewc'
    germanywestcentral: 'gewc'
  }

  settings: {
    enforceLowerCase: {
      default: true
      'Microsoft.ContainerRegistry/registries': true
      'Microsoft.Storage/storageAccounts': true
    }

    delimiter: {
      default: '-'
      'Microsoft.ContainerRegistry/registries': ''
      'Microsoft.Storage/storageAccounts': ''
    }

    format: {
      IDENTIFIER: '{0:0000}'
      DISK_LUN: '{0:00}'
      INDEX: '{0:00}'
    }

    validate: {
      DISK_LUN: {
        range: [0, 10]
      }
      DISK_TYPE: {
        set: [
          'osdisk'
          'datadisk'
          'shareddisk'
        ]
      }
    }
  }

  /*
    NOTE:
    - The key should always be the resource type without the api-version. (So there is no confusion, when calling the function, which type to enter.)
    - Segments for each pattern are seperated by '.'
    - Parameters are defined with '<' and '>'
    - Optional Parameters are defined with '<~' and '>'
    - Everything else is treated as a static string value


    SPECIAL PARAMETERS:
    The following only applies for modules, that correctly implement the naming schema.
    - <INDEX>: should always point to the current index in an iteration. (For example with multiple subnets)
    - <KEY>: should always point to the current key in an iteration. (When iterating over objects with items())
    - <LOCATION>: should always point to the location of the resource.
    - <UNIQUE_STRING_N>: is a unique id based on the deployment name. (N can be any number between 0 and 9)
  */

  patternSegmenter: '.'
  patterns: {
    'Microsoft.Subscription/alias': '<COMPANY>.<NAME>.<ENVIRONMENT>.subs.<IDENTIFIER>'
    'Microsoft.Resources/resourceGroups': 'rg.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'

    // 
    'Microsoft.KeyVault/vaults': 'kv.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<UNIQUE_STRING_5>'
    'Microsoft.ManagedIdentity/userAssignedIdentities': 'id.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'
    'Microsoft.Storage/storageAccounts': 'st.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'

    // Compute
    'Microsoft.Web/sites/functions': 'func.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'
    'Microsoft.Compute/disks': '<DISK_TYPE>.<DISK_LUN>.<NAME>'

    // Container
    'Microsoft.ContainerRegistry/registries': 'acr.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<UNIQUE_STRING_5>'

    // Network
    'Microsoft.Network/networkSecurityGroups': 'nsg..<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'
    'Microsoft.Network/virtualNetworks': 'vnet.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'
    'Microsoft.Network/virtualNetworks/subnets': 'snet.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'
    'Microsoft.Network/publicIPAddresses': 'pip.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'
    'Microsoft.Network/ApplicationGateways': 'appgw.<~PREFIX>.<LOCATION>.<ENVIRONMENT>.<NAME>.<~INDEX>'
  }
}

/*

  Exported Naming Generation Function

*/

@export()
func nameGenerator(resourceType string, schema object, parameters object) string =>
  last([
    /*

      Validation for missing required parameters.

    */

    // map__required_Present
    map(
      // filter__required_Filter
      filter(
        // map__required_Transform
        map(
          split(schema.patterns[resourceType], schema.patternSegmenter),
          //
          // Transform segments into objects for easier handling
          required_Transform =>
            ({
              value: replace(replace(replace(replace(required_Transform, '<', ''), '>', ''), '~', ''), '_', '')
              isParam: startsWith(required_Transform, '<') && endsWith(required_Transform, '>')
              isOptional: startsWith(required_Transform, '<~')
            })
        ),
        //
        // Filter out for conditions:
        // - isParam: Only parameters are required
        // - isOptional: Optional parameters are not required
        // - specialParams: Special params are not provided via parameters
        required_Filter =>
          required_Filter.isParam && !required_Filter.isOptional && !startsWith(required_Filter.value, 'UNIQUESTRING')
      ),
      //
      // Filter out all required parameters that are not provided
      // NOTE: 
      // Bicep apperently is case-insensitive here
      // 'customparameter', 'CUSTOMPARAMETER', etc. all access 'customParameter' regardless of casing
      required_Present => parameters[required_Present.value]
    )

    /*

      Validation for parameter being in correct number range.

    */
    // map__validation_Error
    map(
      // filter__validation_Valid
      filter(
        // map__validation_Apply
        map(
          // filter__validation_Filter
          filter(
            // map__validation_Transform
            map(
              items(schema.settings.validate),

              //
              // Transform validation settings into objects for easier handling
              validation_Transform =>
                ({
                  key: validation_Transform.key
                  value: parameters[?replace(validation_Transform.key, '_', '')]

                  validations: {
                    set: {
                      enabled: !empty(validation_Transform.value.?set)
                      value: validation_Transform.value.?set ?? []
                    }

                    range: {
                      enabled: !empty(validation_Transform.value.?range)
                      value: validation_Transform.value.?range ?? [0, 0]
                    }
                  }
                })
            ),
            //
            // Filter out empty parameter values
            // Check for required parameters is already done above
            // empty() can't be used here, because of possible integer values.
            validation_Filter => null != validation_Filter.value
          ),
          validation_Apply =>
            ({
              key: validation_Apply.key
              value: validation_Apply.value
              validations: validation_Apply.validations

              RangeValid: validation_Apply.validations.range.enabled
                ? validation_Apply.value >= validation_Apply.validations.range.value[0] && validation_Apply.value <= validation_Apply.validations.range.value[1]
                : true

              SetValid: validation_Apply.validations.set.enabled
                ? contains(validation_Apply.validations.set.value, validation_Apply.value)
                : true
            })
        ),
        //
        // Filter out all that have failed validation
        validation_Valid => !validation_Valid.RangeValid || !validation_Valid.SetValid
      ),
      validation_Error =>
        ({
          setInvalid: !validation_Error.SetValid
            ? parameters['${validation_Error.key} with ${validation_Error.value} is not in set: ${validation_Error.validations.set.value}']
            : null
          rangeInvalid: !validation_Error.RangeValid
            ? parameters['${validation_Error.key} with ${validation_Error.value} is not in range: ${validation_Error.validations.range.value}']
            : null
        })
    )

    /*

      Final generating of name, after all checks are run.

    */
    join(
      // map__segment_Unpack
      map(
        // map__segment_Lowercase
        map(
          // filter__segment_Filter
          filter(
            // map__segment_Parameter
            map(
              // map__segment_Tranform
              map(
                // map__segment_Transform
                map(
                  // map__segment_Special
                  map(
                    split(schema.patterns[resourceType], schema.patternSegmenter),

                    //
                    // Take care of special segments: => <LOCATION>, <UNIQUE_STRING>, etc.
                    segment_Special =>
                      segment_Special == '<LOCATION>'
                        ? schema.locations[parameters.location]
                        : startsWith(segment_Special, '<UNIQUE_STRING_')
                            ? substring(uniqueString(deployment().name), 0, int(substring(segment_Special, 15, 1)))
                            : segment_Special
                  ),

                  //
                  // Transform segments into objects for easier handling
                  segment_Transform =>
                    ({
                      value: segment_Transform
                      isParam: startsWith(segment_Transform, '<') && endsWith(segment_Transform, '>')

                      // Below are only relvent, when isParam is true
                      keyWord: replace(replace(replace(segment_Transform, '<', ''), '>', ''), '~', '')
                    })
                ),

                //
                // Transform segments into objects for easier handling
                segment_Transform =>
                  ({
                    value: segment_Transform.value
                    isParam: segment_Transform.isParam

                    enforceLowerCase: schema.settings.enforceLowerCase[?resourceType] ?? schema.settings.enforceLowerCase.default

                    // Below are only relvent, when isParam is true
                    keyWord: segment_Transform.keyWord
                    parameter: replace(segment_Transform.keyWord, '_', '')
                  })
              ),

              //
              // Replace segments in pattern with correct parameters, if it is a parameter < >
              segment_Parameter =>
                ({
                  isParam: segment_Parameter.isParam
                  keyWord: segment_Parameter.keyWord
                  parameter: segment_Parameter.parameter

                  enforceLowerCase: segment_Parameter.enforceLowerCase

                  // use value as is, if it is not a parameter or format it with parameters
                  value: segment_Parameter.isParam
                    ? format(
                        schema.settings.format[?segment_Parameter.keyWord] ?? '{0}',
                        parameters[?segment_Parameter.parameter]
                      )
                    : segment_Parameter.value
                })
            ),

            //
            // Filter out empty segment and unmatched segments before join.
            segment_Filter => !empty(segment_Filter.value)
          ),

          //
          // Enforce all lowercase, if defined in schema.
          segment_Lowercase =>
            ({
              value: segment_Lowercase.enforceLowerCase ? toLower(segment_Lowercase.value) : segment_Lowercase.value
            })
        ),

        // 
        // Unpack object and join segments to a string
        segment_Unpack => segment_Unpack.value
      ),

      //
      // Join with delimiter for resource, or fallback to default delimiter.
      schema.settings.delimiter[?resourceType] ?? schema.settings.delimiter.default
    )
  ])
