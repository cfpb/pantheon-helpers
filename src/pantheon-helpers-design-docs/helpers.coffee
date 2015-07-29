_ = require('underscore')
try
  shared = require('lib/shared')
catch
  shared = {}
  start = 'start'
  getRow = 'getRow'
  send = 'send'

h = {}

h.shared = shared

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

h.sendNakedList = (getRow, start, send, rowTransform) ->
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
      h.sendNakedList(getRow, start, send, (row) ->
        doc = row.doc
        if h.shared.getDocType(doc) != docType
          throw 'skip'
        return h.shared.prepDoc(doc)
      )

h.lists =
  get_prepped: (header, req) ->
    ###
    must call with {get_docs: true}
    run all document through the appropriate prepDoc function defined in shared.prepDocFns
    ###
    h.sendNakedList(getRow, start, send, (row) -> h.shared.prepDoc(row.doc))


  get_values: (header, req) ->
    ###
    return only the value from the passed view's map function
    ###
    h.sendNakedList(getRow, start, send, (row) -> row.value)


h.shows =
  get_prepped: (doc, req) ->
    ###
    return the document after running through shared.prepDoc
    ###
    preppedDoc = h.shared.prepDoc(doc)
    return h.JSONResponse(preppedDoc)

module.exports = h
