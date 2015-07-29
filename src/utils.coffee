_ = require('underscore')
{exec} = require 'child_process'

u =
  mk_objs: (obj, path_array, val={}) ->
    ###
    make a set of nested object.

    obj = {'x': 1}
    mk_objs(obj, ['a', 'b'], ['1'])
    # returns []
    # obj now equals {'x': 1, 'a': {'b': ['1']}}

    return the val
    ###
    if not path_array.length
      return obj
    path_part = path_array.shift()
    if not obj[path_part]
      if path_array.length
        obj[path_part] = {}
      else
        obj[path_part] = val
    else if path_array.length and _.isArray(obj[path_part])
      throw new Error('item at "' + path_part + '" must be an Object, but it is an Array.')
    else if path_array.length and not _.isObject(obj[path_part])
      throw new Error('item at "' + path_part + '" must be an Object, but it is a ' + typeof(obj[path_part]) + '.')
    return u.mk_objs(obj[path_part], path_array, val)

u.process_resp = (opts, callback) ->
  ###
  process a request HTTP response. return a standardized
  error regardless of whether there was a transport error or a server error
  opts is a hash with an optional:
    ignore_codes - array of error codes to ignore, or if 'all' will ignore all http error codes
    body_only - boolean whether to return the body or the full response
  ###
  if typeof opts == 'function'
    callback = opts
    opts = {}
  ignore_codes = opts.ignore_codes or []

  is_http_err = (resp) ->
    if ignore_codes == 'all' or
       resp.statusCode < 400 or 
       resp.statusCode in (ignore_codes or [])
      return false
    else
      return true

  (err, resp, body) ->
    if err or is_http_err(resp)
      req = resp?.req or {}
      req = _.pick(req, '_headers', 'path', 'method')
      err = {err: err, msg: body, code: resp?.statusCode, req: req}
    if opts.body_only
      return callback(err, body)
    else
      return callback(err, resp, body)

u.deepExtend = (target, source) ->
  ###
  recursively extend an object.
  does not recurse into arrays
  ###
  for k, sv of source
    tv = target[k]
    if tv instanceof Array
      target[k] = sv
    else if typeof(tv) == 'object' and typeof(sv) == 'object'
      target[k] = u.deepExtend(tv, sv)
    else
      target[k] = sv
  return target

u.proxyExec = (cmd, process, callback) ->
  ###
  proxy stdout/stderr to process;
  call optional callback when done
  return child process
  ###
  cp = exec(cmd)
  cp = exec(cmd)
  cp.stdout.pipe(process.stdout)
  cp.stderr.pipe(process.stderr)
  cp.on('exit', (code) ->
    if code
      return process.exit(code)
    else if _.isFunction(callback)
      return callback(code)
  )
  return cp

u.removeInPlace = (container, value) ->
  if value in container
    i = container.indexOf(value)
    container.splice(i, 1)

u.removeInPlaceById = (container, record) ->
  ###
  given a record hash with an id key, look through the container array
  to find an item with the same id as record. If such an item exists,
  remove it in place.
  return the deleted record or undefined
  ###
  for item, i in container
    if item.id == record.id
      existing_record = container.splice(i, 1)[0]
      return existing_record
  return undefined

u.insertInPlace = (container, value) ->
  if value not in container
    container.push(value)

u.insertInPlaceById = (container, record) ->
  ###
  given a record hash with an id key, add the record to the container
  if an item with the record's key is not already in the container
  return the existing or new record.
  ###
  existing_record = _.findWhere(container, {id: record.id})
  if existing_record
    return existing_record
  else
    container.push(record)
    return record

u.formatId = (id, typeName) ->
  ###
  return an id ready for CouchDB with the typeName prepended to the id.
  ###
  if id.indexOf(typeName + '_') == 0
    return id
  else
    return typeName + '_' + id

module.exports = u
