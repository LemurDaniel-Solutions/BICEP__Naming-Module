@export()
func nameGenerator(
  resourceType string,
  id string?,
  schema object,
  parameters {
    index: int?
    overwrite: string?
    *: string?
  }
) string =>
  nameGenerator2(
    // [Pattern]        | Patterns prefer ID over KIND, but will fallback to KIND
    selectPattern(schema.patterns, split(resourceType, '::')[0], split(resourceType, '::')[?1], id),

    // [Resource Type]  | 
    resourceType,

    // [Schema]         | Set empty default in schema, when not provided
    union(
      {
        indexModifier: 0
        mappings: {}
      },
      schema
    ),

    // [Parameters]     | Set empty default in parameters, when not provided
    union(
      {
        // Default index is 1, when not set
        index: 1
        key: null
        id: id
        kind: split(resourceType, '::')[?1] ?? id

        // Abbreviation prefer KIND over ID, but will fallback to ID.
        type: selectAbbreviation(schema.abbreviations, split(resourceType, '::')[0], split(resourceType, '::')[?1], id)
      },
      parameters
    )
  )

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
///////   Helper functions for selecting abbreviations and patterns

func selectAbbreviation(abbreviations object, resourceType string, kind string?, id string?) string =>
  // Abbreviations prefers KIND over ID, but will fallback to ID
  // This check in the following order for an abbreviation: 
  // - Match to <resourceType>::<kind>
  // - Match to <resourceType>::<id>
  // - Match to <resourceType>::default
  // - Match to <resourceType>
  // - Fail with an error, if no abbreviation is found
  filter(
    [
      abbreviations[?'${resourceType}::${kind ?? id ?? 'default'}']
      abbreviations[?resourceType]
    ],
    abbreviation => !empty(abbreviation)
  )[?0] ?? fail('No abbreviation found for resourceType: ${resourceType} and kind: ${kind ?? 'default'}')

func selectPattern(patterns object, resourceType string, kind string?, id string?) string =>
  // Patterns prefers ID over KIND, but will fallback to KIND
  // This check in the following order for a pattern:
  // - Match to <resourceType> (Object)
  //   - Match for specific ID
  //   - Match for specific KIND
  //   - Match to DEFAULT
  // - If no previous match, check for INLINE::<resourceType>
  // - If no previous match, check for default pattern
  // - Fail with an error, if no pattern is found
  filter(
    [
      patterns[?resourceType][?id ?? kind ?? 'default']
      patterns[?resourceType].?default
      patterns[?'INLINE::${resourceType}']
      patterns.?default
    ],
    pattern => !empty(pattern)
  )[?0] ?? fail('No pattern found for resourceType: ${resourceType} and kind: ${kind ?? 'default'}')

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
///////   Name generation function

func nameGenerator2(pattern string, resourceType string, schema object, parameters object) string =>
  // When OVERWRITE is set, the naming schema is not used and the name is directly returned.
  parameters.?OVERWRITE ?? last([
    validationChecker(schema.?validate ?? {}, resourceType, parameters)

    //////////////////////////////////////////////////////////////////////////////////
    ///////   Final generation of the name based on the pattern and parameters
    [
      join(
        map(
          filter(
            // Splits and replaces all segments based on the naming schema and parameters
            segment_Finalisation(pattern, schema, parameters),

            // Removes all empty segments
            segment => !empty(segment)
          ),

          // Enforces the lower case rule when specified in the schema
          segment =>
            schema.enforceLowerCase[?resourceType] ?? schema.enforceLowerCase.default ? toLower(segment) : segment
        ),
        //
        // Join splittet parameters into a single string again.
        ''
      )
    ][?0] ?? fail('\n\nERROR: Naming Generation failed.')
  ])

//////////////////////////////////////////////////////////////////////////////////
///////   call the necessary methods to transform and make some final adjustments to the segments.

func segment_Finalisation(pattern string, schemaRef object, paramRef object) array =>
  map(
    // We are adding a '&' before and after each parameter, so that we can split it and get the correct segments.
    // Optimally this is some character that nobody in his right mind would use for naming.
    // Also we are not using ';', '?', as with those we are already controling custom formatting and optional parameters.
    // We are also not using the delimiter, because we may not want a delimiter between some segments and some resources don't have delimiters. (like storage accounts, container registries, etc.)
    split(replace(replace(pattern, '<', '&<'), '>', '>&'), '&'),

    // Transforms each segment by replacing it with the parameters
    value =>
      segment_Transform(
        // [SchemaRef]    | The naming schema
        schemaRef,
        // [ParamRef]     | The naming parameters
        paramRef,
        //
        // [value]        | The segment without any control characters like '<', '>', '?'
        replace(replace(replace(replace(value, '<', ''), '>', ''), '?', ''), '_', ''),

        // [isParam]      | true, if the segment starts with '<' and ends with '>'
        startsWith(value, '<') && endsWith(value, '>'),

        // [isOptional]   | true, if the segment contains '?'
        contains(value, '?')
      )
  )

//////////////////////////////////////////////////////////////////////////////////
///////   Transform segments into objects for easier handling

func segment_Transform(schemaRef object, paramRef object, value string, isParam bool, isOptional bool) string =>
  segment_Replace(
    schemaRef,
    paramRef,

    // [value]              | The bare value of the segment, without any control characters like '<', '>', '?']
    value,
    // [isParam]            | true, if the segment starts with '<' and ends with '>']
    isParam,
    // [isOptional]         | true, if the segment contains '?'
    isOptional,
    // [isSpecialKey]   | true, if the segment is a special key word
    length(filter(['INDEX', 'LOCATION', 'UNIQUESTRING'], keyword => startsWith(value, keyword))) > 0,

    // Below are only relvent, when isParam is true

    // The parameter may be in format <PARAMETER_NAME;{0}> or <PARAMETER_NAME>
    // [keyWord]              | The PARAMETER_NAME
    split(value, ';')[0],
    // [formatStr]             | The format defaults to {0}
    split(value, ';')[?1] ?? '{0}',

    // [mapping]         | Searches for the mapping set with the logic above
    schemaRef.mappings[?split(value, ';')[0]] ?? {}
  )

//////////////////////////////////////////////////////////////////////////////////
///////   Replace segments in pattern with correct parameters, if it is a parameter < >

func segment_Replace(
  schemaRef object,
  paramRef object,

  value string,
  isParam bool,
  isOptional bool,
  isSpecialKey bool,

  // Below are only relvent, when isParam is true
  keyWord string,
  formatStr string,
  mapping object
) string =>
  filter(
    [
      // Handle segments that are not parameters
      !isParam ? value : null

      // Handle LOCATION parameter
      keyWord == 'LOCATION' ? sR_Location(paramRef, schemaRef) : null

      // Handle INDEX parameter
      keyWord == 'INDEX' ? sR_Index(paramRef, schemaRef, formatStr) : null

      // Handle UNIQUESTRING_N parameter
      startsWith(keyWord, 'UNIQUESTRING') ? sR_UniqueString_N(keyWord) : null

      // Handle Required Parameters with and without mappings
      !isSpecialKey && isParam && !isOptional ? sR_ParamsRequired(paramRef, mapping, keyWord, formatStr) : null

      // Handle Optional Parameters with and without mappings
      !isSpecialKey && isParam && isOptional ? sR_ParamsOptional(paramRef, mapping, keyWord, formatStr) : null
    ],
    p => !empty(p)
  )[?0] ?? ''

func sR_ParamsOptional(paramRef object, mapping object, parameter string, formatStr string) string =>
  // NOTE: we can NOT use empty for parameters
  // The template function 'empty' expects its parameter to be an object, an array, or a | string. 
  // The provided value is of type 'Integer'
  filter(
    [
      // When mapping is defined we return the mapped value otherwise ''
      contains(mapping, '${paramRef[?parameter]}') ? format(formatStr, mapping[paramRef[parameter]]) : ''

      // When no mapping is defined we return the parameter or ''
      contains(paramRef, parameter) ? format(formatStr, paramRef[parameter]) : ''
    ],
    p => !empty(p)
  )[?0] ?? ''

func sR_ParamsRequired(paramRef object, mapping object, parameter string, formatStr string) string =>
  // NOTE: we can NOT use empty for parameters
  // The template function 'empty' expects its parameter to be an object, an array, or a | string. 
  // The provided value is of type 'Integer'
  last([
    !contains(paramRef, parameter) ? fail('\n\nERROR: Parameter ${parameter} is not defined in the parameters.') : ''

    // length(mapping) > 0 && !contains(mapping, '${paramRef[?parameter]}')
    //   ? fail('\n\nERROR: Mapping for ${paramRef[parameter]} is not defined. \nParameter ${parameter} \nMapped Value ${paramRef[parameter]} \nFound Mappings ${join(map(items(mapping), item => '${item.key} => ${item.value}'), '\n -')}')
    //   : ''

    // Returns:
    // - When Mapping defined: The mapped result                  | For example development => dev
    // - When Mapping not defined: The original parameter value   | For example development
    contains(mapping, '${paramRef[?parameter]}')
      ? format(formatStr, mapping[paramRef[parameter]])
      : format(formatStr, paramRef[parameter])
  ])

func sR_Index(paramRef object, schemaRef object, formatStr string) string =>
  !contains(paramRef, 'index')
    ? fail('\n\nERROR: Parameter index is not defined in the parameters.')
    : format(formatStr, int(paramRef.index) + int(schemaRef.indexModifier))

func sR_UniqueString_N(keyWord string) string =>
  substring(
    uniqueString(resourceGroup().?name ?? subscription().?subscriptionId ?? fail('\n\nERROR: Could not determine unique string')),
    0,
    int(replace(keyWord, 'UNIQUESTRING', ''))
  )

func sR_Location(paramRef object, schemaRef object) string =>
  schemaRef.locations[?paramRef.location] ?? fail('\n\nERROR: Location ${paramRef.location} is not defined in the schema locations.')

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
///////   Validation for parameter being in correct number range.

@description('''
Validates that a parameter value is in a specified set of values.
''')
func validateSet(paramValue string, set string[]) bool =>
  !contains(set, paramValue) ? fail('Parameter value ${paramValue} is not in set: ${set}') : true

@description('''
Validates that a parameter value is in a specified range.
''')
func validateRange(paramValue int, range [int, int]) bool =>
  paramValue < range[0] || paramValue > range[1]
    ? fail('Parameter value ${paramValue} is not in range: [${range[0]} - ${range[1]}]')
    : true

@description('''
This function retrives all relevant validations matching following condition:
- Matches the resource Type (wildcards allowed): Microsoft.Compute/* | Microsoft.Network/virtualNetworks | etc.
- Matches an existing parameter in the provided paramRef
''')
func getRelevantValidations(validations object, resourceType string, paramRef object) array =>
  filter(
    items(filter(items(validations), item => startsWith(item.key, resourceType))[?0] ?? validations.?default ?? {}),
    // Filter out all parameters that are not defined in the paramRef
    paramValidation => contains(paramRef, paramValidation.key)
  )

@description('''
This is a warpper function calling the validation functions for a single parameter.
- calls validateRange if range is defined
- calls validateSet if set is defined
''')
func validationWrapper(
  paramRef object,
  paramName string,
  validation {
    range: [int, int]?
    set: string[]?
  }
) bool =>
  reduce(
    [
      !empty(validation.?range) ? validateRange(int(paramRef[?paramName]), validation.?range ?? [0, 0]) : true

      !empty(validation.?set) ? validateSet(paramRef[?paramName], validation.?set ?? []) : true
    ],
    true,
    (acc, next) => acc && next
  )

func validationChecker(
  validations {
    // resourceType
    *: {
      // Parameter name
      *: {
        range: [int, int]?
        set: string[]?
      }
    }
  },
  resourceType string,
  paramRef object
) object[] =>
  filter(
    getRelevantValidations(validations, resourceType, paramRef),
    // Validate each parameter with the validation functions
    paramValidation => validationWrapper(paramRef, paramValidation.key, paramValidation.value)
  )
