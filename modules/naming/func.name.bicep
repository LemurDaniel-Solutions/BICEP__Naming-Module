@export()
func nameGenerator(
  resourceType string,
  kind string?,
  schema object,
  parameters {
    index: int?
    overwrite: string?
    *: string?
  }
) string =>
  nameGenerator2(
    // Prefer any explicit kind over the one in the resourceType: kind ?? split(resourceType, '::')[?1]
    selectPattern(schema.patterns, split(resourceType, '::')[0], kind ?? split(resourceType, '::')[?1]),
    resourceType,
    schema,
    union(
      {
        key: null
        // Default index is 1, wenn not set
        index: 1
        type: selectAbbreviation(schema.abbreviations, split(resourceType, '::')[0], split(resourceType, '::')[?1])
      },
      parameters
    )
  )

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
///////   Helper functions for selecting abbreviations and patterns

func selectAbbreviation(abbreviations object, resourceType string, kind string?) string =>
  // This check in the following order for an abbreviation: 
  // - Match to <resourceType>::<kind>
  // - Match to <resourceType>::default
  // - Match to <resourceType>
  // - Fail with an error, if no abbreviation is found
  filter(
    [
      abbreviations[?'${resourceType}::${kind ?? 'default'}']
      abbreviations[?'${resourceType}::default']
      abbreviations[?resourceType]
    ],
    abbreviation => !empty(abbreviation)
  )[?0] ?? fail('No abbreviation found for resourceType: ${resourceType} and kind: ${kind ?? 'default'}')

func selectPattern(patterns object, resourceType string, kind string?) string =>
  // This check in the following order for a pattern:
  // - Match to MAP::<resourceType>
  //   - Match for a specific kind, if provided
  //   - Match to default kind, if no specific kind is provided
  // - If no previous match, check for SINGLE::<resourceType>
  // - If no previous match, check for default pattern
  // - Fail with an error, if no pattern is found
  filter(
    [
      patterns[?'MAP::${resourceType}'][?kind ?? 'default']
      patterns[?'MAP::${resourceType}'].?default
      patterns[?'SINGLE::${resourceType}']
      patterns.?default
    ],
    pattern => !empty(pattern)
  )[?0] ?? fail('No pattern found for resourceType: ${resourceType} and kind: ${kind ?? 'default'}')

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
///////   Validation for parameter being in correct number range.

func nameGenerator2(pattern string, resourceType string, schema object, parameters object) string =>
  // When OVERWRITE is set, the naming schema is not used and the name is directly returned.
  parameters.?OVERWRITE ?? last([
    checkValidations(schema, resourceType, parameters)

    //////////////////////////////////////////////////////////////////////////////////
    ///////   Final generation of the name based on the pattern and parameters
    first([
      join(
        segment_Finalisation(
          // We are adding a '&' before and after each parameter, so that we can split it and get the correct segments.
          // Optimally this is some character that nobody in his right mind would use for naming.
          // Also we are not using ';', '?', as with those we are already controling custom formatting and optional parameters.
          // We are also not using the delimiter, because we may not want a delimiter between some segments and some resources don't have delimiters. (like storage accounts, container registries, etc.)
          split(replace(replace(pattern, '<', '&<'), '>', '>&'), '&'),
          resourceType,
          schema,
          parameters
        ),

        //
        // Join splittet parameters into a single string again.
        ''
      )

      // This is still in an array of 1, so we can use the map-function on the single-value array.
    ]) ?? fail('ERROR: Naming Generation failed.')
  ])

//////////////////////////////////////////////////////////////////////////////////
///////   call the necessary methods to transform and make some final adjustments to the segments.

func segment_Finalisation(segmentList string[], resourceType string, schemaRef object, paramRef object) array =>
  map(
    filter(
      // Transform and replace segments in the pattern
      map(segmentList, value => segment_Transform(value, resourceType, schemaRef, paramRef)),

      // Filter out empty segments and unmatched segments before join.
      segment_filter => !empty(segment_filter.value)
    ),
    // Enforce all lowercase, if defined in schema and unpack the object
    segnment_lowercase =>
      segnment_lowercase.enforceLowerCase ? toLower(segnment_lowercase.value) : segnment_lowercase.value
  )

//////////////////////////////////////////////////////////////////////////////////
///////   Transform segments into objects for easier handling

func segment_Transform(value string, resourceType string, schemaRef object, paramRef object) object =>
  segment_Transform2(
    schemaRef,
    paramRef,
    //
    // value: The segment without any control characters like '<', '>', '?'
    replace(replace(replace(value, '<', ''), '>', ''), '?', ''),
    // isParam: true, if the segment starts with '<' and ends with '>'
    startsWith(value, '<') && endsWith(value, '>'),
    // isOptional: true, if the segment contains '?'
    contains(value, '?'),
    // enforceLowerCase: true, if the schema defines it for the resourceType or default
    schemaRef.enforceLowerCase[?resourceType] ?? schemaRef.enforceLowerCase.default
  )

func segment_Transform2(
  schemaRef object,
  paramRef object,
  value string,
  isParam bool,
  isOptional bool,
  enforceLowerCase bool
) object =>
  segment_Replace(
    schemaRef,
    paramRef,

    // value: The bare value of the segment, without any control characters like '<', '>', '?'
    value,
    // isParam: true, if the segment starts with '<' and ends with '>'
    isParam,
    // isOptional: true, if the segment contains '?'
    isOptional,
    // enforceLowerCase: true, if the schema defines it for the resourceType or default
    enforceLowerCase,

    // Below are only relvent, when isParam is true

    // The parameter may be in format <PARAMETER_NAME;{0}> or <PARAMETER_NAME>
    // So we need to split it:
    // - First segment is the parameter name
    // - Second segment is the format, defaulting to '{0}'
    // keyWord:
    split(value, ';')[0],
    // format: split(segment, ';')[?1] ?? '{0}'
    split(value, ';')[?1] ?? '{0}',

    // When the keyWord is DISK_LUN, we want to search for DiskLun in parameters. 
    // split(segment_Transform.segment, ';')[0], '_', '')
    // Turns <DISK_LUN;{0}> => into DISKLUN
    // parameter: replace(split(segment, ';')[0], '_', '')
    replace(split(value, ';')[0], '_', ''),
    // mapping: schema.mappings[?replace(split(segment, ';')[0], '_', '')] ?? {}
    schemaRef.mappings[?replace(split(value, ';')[0], '_', '')] ?? {}
  )

//////////////////////////////////////////////////////////////////////////////////
///////   Replace segments in pattern with correct parameters, if it is a parameter < >

func segment_Replace(
  schemaRef object,
  paramRef object,

  value string,
  isParam bool,
  isOptional bool,

  enforceLowerCase bool,

  // Below are only relvent, when isParam is true
  keyWord string,
  formatStr string,
  parameter string,
  mapping object
) {
  enforceLowerCase: bool
  value: string
} => {
  enforceLowerCase: enforceLowerCase

  // Replace segments in pattern with correct parameters, if it is a parameter < >
  /*
    The Filter Variant seemed to be more readable:
    - filter([''], b => isParam)
    - isParam ? [''] : []
  */
  value: concat(
    // Handle segments that are not parameters
    map(filter([''], b => !isParam), b => value),

    // Handle LOCATION parameter
    map(filter([''], b => keyWord == 'LOCATION'), b => schemaRef.locations[paramRef.location]),

    // Handle INDEX parameter
    map(
      filter([''], b => keyWord == 'INDEX'),
      b => format(formatStr, int(paramRef.index) + int(schemaRef.indexModifier))
    ),

    // Handle UNIQUE_STRING_N parameter
    map(
      filter([''], b => startsWith(keyWord, 'UNIQUE_STRING_')),
      b => substring(uniqueString(resourceGroup().name), 0, int(substring(keyWord, 14, 1)))
    ),

    // Handle parameters with mappings that are not optional
    map(
      filter([''], b => length(mapping) > 0 && isParam && !isOptional),
      b =>
        contains(paramRef, parameter)
          ? format(formatStr, mapping[paramRef[parameter]])
          : fail('ERROR: Parameter ${parameter} is not defined in the mapping.')
    ),

    // Handle optional parameters with mappings and replace with nothing ''
    map(
      filter([''], b => !empty(mapping[?parameter]) && isParam && isOptional),
      b => contains(paramRef, parameter) ? format(formatStr, mapping[paramRef[parameter]]) : ''
    ),

    // Handle optional parameters and replace with nothing ''
    map(
      filter([''], b => isParam && isOptional),
      b => contains(paramRef, parameter) ? format(formatStr, paramRef[parameter]) : ''
    )
  )[?0] ?? paramRef[?parameter] ?? fail('ERROR: Parameter ${parameter} is not defined in the parameters.')
}

//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////
///////   Validation for parameter being in correct number range.

func checkValidations(schema object, resourceType string, parameters object) array => [
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
            // These applies validation settings, if they are defined in the schema.
            // First default settings are searched, then settings for the specific resource type are checked for.
            items(union(
              schema.?validate.?default ?? {},
              // It is designed to search for types that start with the resourceType, so that it can be used for multiple types.
              // For eaxample Microsoft.Compute/ => applies to all subtypes of Microsoft.Compute
              schema.?validate[?filter(objectKeys(schema.?validate ?? {}), key => startsWith(resourceType, key))[?0] ?? ''] ?? {}
            )),

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
              ? int(validation_Apply.value) >= validation_Apply.validations.range.value[0] && int(validation_Apply.value) <= validation_Apply.validations.range.value[1]
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
          ? fail('${validation_Error.key} with ${validation_Error.value} is not in set: ${validation_Error.validations.set.value}')
          : null
        rangeInvalid: !validation_Error.RangeValid
          ? fail('${validation_Error.key} with ${validation_Error.value} is not in range: ${validation_Error.validations.range.value}')
          : null
      })
  )
]
