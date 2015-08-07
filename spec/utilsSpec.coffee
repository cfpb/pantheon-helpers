utils = require('../lib').utils
Promise = require('../lib/promise')

describe 'mkObjs', () ->
  it 'traverses existing objects to return object at path', () ->
    obj = {a: {b: {c: 'd'}}}
    actual = utils.mkObjs(obj, ['a', 'b', 'c'])
    expect(actual).toEqual('d')

  it 'sets the item at path to be val, if the item does not exist', () ->
    obj = {a: {b: {}}}
    val = {}
    utils.mkObjs(obj, ['a', 'b', 'c'], val)    
    expect(obj.a.b.c).toBe(val)

  it 'defaults val to be an empty object', () ->
    obj = {a: {b: {}}}
    utils.mkObjs(obj, ['a', 'b', 'c'])
    expect(obj.a.b.c).toEqual({})

  it 'creates any missing objects on path', () ->
    obj = {a: {}}
    actual = utils.mkObjs(obj, ['a', 'b', 'c'])
    expect(obj).toEqual({a: {b: {c: {}}}})

  it 'returns the created object at path', () ->
    obj = {a: {}}
    actual = utils.mkObjs(obj, ['a', 'b', 'c'])
    expect(actual).toBe(obj.a.b.c)

  it 'errors if a traversed item is not an object', () ->
    expect(() ->
      obj = {a: 1}
      actual = utils.mkObjs(obj, ['a', 'b', 'c'])
    ).toThrow()

  it 'errors if a traversed item is an array', () ->
    expect(() ->
      obj = {a: []}
      actual = utils.mkObjs(obj, ['a', 'b', 'c'])
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

describe 'getActor', () ->
  beforeEach () ->
    this.user1 = {name: 'user1', _id: 'ord.couchdb.user:user1', _rev: '12'}
    this.dbClient = {
      get: jasmine.createSpy('get').andReturn(Promise.resolve(this.user1))
    }
    this.client = {
      use: jasmine.createSpy('use').andReturn(this.dbClient)
    }
    this.couchUtils = {
      get_system_user:  jasmine.createSpy('get_system_user').andReturn(this.client),
      conf: {COUCHDB: {SYSTEM_USER: 'systemUser'}},
    }

  it 'returns the user from the database given the userName', (done) ->
    cut = utils.getActor
    cut(this.couchUtils, 'user1').then((user) =>
      expect(this.dbClient.get).toHaveBeenCalledWith('org.couchdb.user:user1', 'promise')
      expect(user).toEqual(this.user1)
      done()
    ).catch(done)

  it 'returns the existing user object without hitting DB if userName is a user objec', (done) ->
    originalUser = {name: 'user1'}

    cut = utils.getActor
    cut(this.couchUtils, originalUser).then((user) =>
      expect(this.dbClient.get).not.toHaveBeenCalled()
      expect(user).toBe(originalUser)
      done()
    ).catch(done)

  it 'returns a system user stub if the system user is requested', (done) ->
    cut = utils.getActor
    cut(this.couchUtils, 'systemUser').then((user) =>
      expect(this.dbClient.get).not.toHaveBeenCalled()
      expect(user).toEqual({name: 'systemUser', roles: []})
      done()
    ).catch(done)
