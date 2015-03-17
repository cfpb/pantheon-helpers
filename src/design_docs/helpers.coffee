try
  _ = require('underscore')
catch err
  _ = require('lib/underscore')

h = {}

h.mk_objs = (obj, path_array, val={}) ->
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
  return h.mk_objs(obj[path_part], path_array, val)

module.exports = h
