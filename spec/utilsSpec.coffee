utils = require('../lib').utils

describe 'mk_objs', () ->
  it 'traverses existing objects to return object at path', () ->
    obj = {a: {b: {c: 'd'}}}
    actual = utils.mk_objs(obj, ['a', 'b', 'c'])
    expect(actual).toEqual('d')

  it 'sets the item at path to be val, if the item does not exist', () ->
    obj = {a: {b: {}}}
    val = {}
    utils.mk_objs(obj, ['a', 'b', 'c'], val)    
    expect(obj.a.b.c).toBe(val)

  it 'defaults val to be an empty object', () ->
    obj = {a: {b: {}}}
    utils.mk_objs(obj, ['a', 'b', 'c'])
    expect(obj.a.b.c).toEqual({})

  it 'creates any missing objects on path', () ->
    obj = {a: {}}
    actual = utils.mk_objs(obj, ['a', 'b', 'c'])
    expect(obj).toEqual({a: {b: {c: {}}}})

  it 'returns the created object at path', () ->
    obj = {a: {}}
    actual = utils.mk_objs(obj, ['a', 'b', 'c'])
    expect(actual).toBe(obj.a.b.c)

  it 'errors if a traversed item is not an object', () ->
    expect(() ->
      obj = {a: 1}
      actual = utils.mk_objs(obj, ['a', 'b', 'c'])
    ).toThrow()

  it 'errors if a traversed item is an array', () ->
    expect(() ->
      obj = {a: []}
      actual = utils.mk_objs(obj, ['a', 'b', 'c'])
    ).toThrow()


describe 'process_resp', () ->
  it 'returns a standardized error message when there is an http error code', (done) ->
    callback = (err) ->
      expect(err).toEqual({err: null, msg: 'body', code: 404, req: { _headers : { header : 'header1' }, path : 'requested/path', method : 'GET' }})
      done()

    utils.process_resp({ignore_codes: [409]}, callback)(null, {statusCode:404, req: {_headers: {header: 'header1'}, path: 'requested/path', method: 'GET'}}, 'body')

  it 'returns a standardized error message when there is a connection error', (done) ->
    callback = (err) ->
      expect(err).toEqual({err: 'ENOENT', msg: null, code: undefined, req: {}})
      done()

    utils.process_resp(callback)('ENOENT', null, null)

  it 'returns the original resp/body when there is an error', (done) ->
    callback = (err, resp, body) ->
      expect(resp).toEqual({statusCode:404})
      expect(body).toEqual('body')
      done()

    utils.process_resp(callback)(null, {statusCode:404}, 'body')

  it 'returns the original resp/body when there is no error', (done) ->
    callback = (err, resp, body) ->
      expect(err).toEqual(null)
      expect(resp).toEqual({statusCode:200})
      expect(body).toEqual('body')
      done()

    utils.process_resp(callback)(null, {statusCode:200}, 'body')

  it 'returns the original resp/body when the error is in the ignore_codes array', (done) ->
    callback = (err, resp, body) ->
      expect(err).toEqual(null)
      expect(resp).toEqual({statusCode:409})
      expect(body).toEqual('body')
      done()

    utils.process_resp({ignore_codes: [409]}, callback)(null, {statusCode:409}, 'body')

  it 'returns only the body when body_only==true', (done) ->
    callback = (err, body) ->
      expect(err).toEqual(null)
      expect(body).toEqual('body')
      done()

    utils.process_resp({body_only: true}, callback)(null, {statusCode:200}, 'body')

# no longer in utils, just in template shared.coffee, but can't test that
# describe 'getDocType', () ->
#   it 'returns `user` when the doc is a user document (id starts with `org.couchdb.user:`', () ->
#     cut = utils.getDocType

#     actual = cut({_id: 'org.couchdb.user:cuwmg483cuhew'})

#     expect(actual).toEqual('user')


#   it 'returns the type as prepended to the _id, and separated by an _', () ->
#     cut = utils.getDocType

#     actual = cut({_id: 'type_cuwmg483cuhew'})

#     expect(actual).toEqual('type')

#   it 'returns null if there is no valid type to be pulled from the id', () ->
#     cut = utils.getDocType

#     actual = cut({_id: '_cuwmg483cuhew'})

#     expect(actual).toEqual(null)


describe 'removeInPlace', () ->
  it 'removes the value from the container array, if already there', () ->
    actual = ['a', 'b', 'c']
    utils.removeInPlace(actual, 'b')
    expect(actual).toEqual(['a', 'c'])

  it 'does nothing if the value is not in the container', () ->
    actual = ['a', 'c']
    utils.removeInPlace(actual, 'b')
    expect(actual).toEqual(['a', 'c'])

describe 'removeInPlaceById', () ->
  it 'removes the record with the matching id, if already there', () ->
    actual = [{id: 1}, {id: 2, val: 'a'}, {id:3}]
    utils.removeInPlaceById(actual, {id: 2})
    expect(actual).toEqual([{id: 1}, {id:3}])

  it 'returns the removed record', () ->
    actual = utils.removeInPlaceById([{id: 1}, {id: 2, val: 'a'}, {id:3}], {id: 2})
    expect(actual).toEqual({id: 2, val: 'a'})

  it 'does nothing if a record with a matching id is not in the container', () ->
    actual = [{id: 1}, {id:3}]
    utils.removeInPlaceById(actual, {id: 2})
    expect(actual).toEqual([{id: 1}, {id:3}])

  it 'returns undefined if nothing deleted', () ->
    actual = utils.removeInPlaceById([{id: 1}, {id:3}], {id: 2})
    expect(actual).toBeUndefined()

describe 'insertInPlace', () ->
  it 'adds the value to the container array, if not already there', () ->
    actual = ['a', 'b']
    utils.insertInPlace(actual, 'c')
    expect(actual).toEqual(['a', 'b', 'c'])

  it 'does nothing if the value is already there', () ->
    actual = ['a', 'b', 'c']
    utils.insertInPlace(actual, 'c')
    expect(actual).toEqual(['a', 'b', 'c'])

describe 'insertInPlaceById', () ->
  it 'adds the record if there is not already a record with a matching id', () ->
    actual = [{id: 1}, {id:3}]
    utils.insertInPlaceById(actual, {id: 2})
    expect(actual).toEqual([{id: 1}, {id:3}, {id: 2}])

  it 'returns the inserted record', () ->
    actual = utils.insertInPlaceById([{id: 1}, {id:3}], {id: 2})
    expect(actual).toEqual({id: 2})

  it 'does nothing if a record with the same id is already there', () ->
    actual = [{id: 1}, {id: 2, val: 'a'}, {id:3}]
    utils.insertInPlaceById(actual, {id: 2})
    expect(actual).toEqual([{id: 1}, {id: 2, val: 'a'}, {id:3}])

  it 'returns the existing record', () ->
    actual = utils.insertInPlaceById([{id: 1}, {id: 2, val: 'a'}, {id:3}], {id: 2})
    expect(actual).toEqual({id: 2, val: 'a'})

describe 'formatId', () ->
  it 'returns the id with the typeName prepended if not already so', () ->
    cut = utils.formatId

    actual = cut('teamid', 'team')

    expect(actual).toEqual('team_teamid')

  it 'returns the id if already prepended with the typeName', () ->
    cut = utils.formatId

    actual = cut('team_teamid', 'team')

    expect(actual).toEqual('team_teamid')
