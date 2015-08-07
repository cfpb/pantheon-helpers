_ = require('underscore')
h = {}

module.exports = (shared, getRow, start, send) ->
  h.JSONResponse = (doc) ->
    ###
    format a proper JSON response for the document
    ###
    return {
      headers: {
        'Content-Type': "application/json"
      }
      body: JSON.stringify(doc),
    }

  h.sendNakedList = (rowTransform) ->
    ###
    lazily send a JSON serialized list of rows,
    each having been transformed by rowTransform.
    If rowTransform throws the string `"skip"`,
    the row will be skipped.
    ###
    start({
      headers: {
        'Content-Type': 'application/json'
      }
    })
    first = true
    send('[')
    while(row = getRow())
      try
        transformedRow = rowTransform(row)
      catch e
        if e == 'skip'
          continue
        else
          throw e

      if first
        first = false
      else
        send(',')

      send(JSON.stringify(transformedRow))
    send(']')

  h.listGenerators =
    get_prepped_of_type: (docType) ->
      ###
      returns a list function
      must call with {get_docs: true}
      only return documents of the specified type
      run all document through the appropriate prepDoc function defined in shared.prepDocFns
      ###
      return (header, req) ->
        h.sendNakedList((row) ->
          doc = row.doc
          if shared.getDocType(doc) != docType
            throw 'skip'
          return shared.prepDoc(doc)
        )

  h.lists =
    get_prepped: (header, req) ->
      ###
      must call with {get_docs: true}
      run all document through the appropriate prepDoc function defined in shared.prepDocFns
      ###
      h.sendNakedList((row) -> shared.prepDoc(row.doc))

    get_values: (header, req) ->
      ###
      return only the value from the passed view's map function
      ###
      h.sendNakedList((row) -> row.value)

    get_first_prepped: (header, req) ->
      ###
      must call with {get_docs: true}
      get the first returned document and run it through the prepDoc function
      ###
      row = getRow()
      if row
        return h.shows.get_prepped(row.doc)
      else
        throw(['error', 'not_found', 'document matching query does not exist'])


  h.shows =
    get_prepped: (doc, req) ->
      ###
      return the document after running through shared.prepDoc
      ###
      preppedDoc = shared.prepDoc(doc)
      return h.JSONResponse(preppedDoc)

  return h
