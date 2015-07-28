doAction = require('../lib/doAction')
Promise = require('../lib/promise')
validate = require('../lib/validateDocUpdate')
    # this.nano_user = jasmine.createSpy('use')
    # this.couchUtils = {
    #   getUuid: jasmine.createSpy('getUuid')
    #   use: jasmine.createSpyObj('use', [''])
    # }


describe 'getUser', () ->
  beforeEach () ->
    this.user1 = {name: 'user1', _id: 'ord.couchdb.user:user1', _rev: '12'}
    this.dbClient = {
      get: jasmine.createSpy('get').andReturn(Promise.resolve(this.user1))
    }
    this.client = {
      use: jasmine.createSpy('use').andReturn(this.dbClient)
    }

  it 'returns the user from the database given the userName', (done) ->
    cut = doAction.getUser
    cut(this.client, 'system', 'user1').then((user) =>
      expect(this.dbClient.get).toHaveBeenCalledWith('org.couchdb.user:user1', 'promise')
      expect(user).toEqual(this.user1)
      done()
    ).catch(done)

  it 'returns the existing user object without hitting DB if userName is a user objec', (done) ->
    originalUser = {name: 'user1'}

    cut = doAction.getUser
    cut(this.client, 'system', originalUser).then((user) =>
      expect(this.dbClient.get).not.toHaveBeenCalled()
      expect(user).toBe(originalUser)
      done()
    ).catch(done)

  it 'returns a system user stub if the system user is requested', (done) ->
    cut = doAction.getUser
    cut(this.client, 'system', 'system').then((user) =>
      expect(this.dbClient.get).not.toHaveBeenCalled()
      expect(user).toEqual({name: 'system', roles: []})
      done()
    ).catch(done)


describe 'getDoc', () ->
  beforeEach () ->
    this.user1 = {name: 'user1', _id: 'ord.couchdb.user:user1', _rev: '12'}
    this.dbClient = {
      get: jasmine.createSpy('get').andReturn(Promise.resolve(this.user1))
    }
    this.client = {
      use: jasmine.createSpy('use').andReturn(this.dbClient)
      getUuid: jasmine.createSpy('getUuid').andReturn(Promise.resolve('new_uuid'))
    }

  it 'returns the doc with the docId from the dbName database', (done) ->
    doc = {_id: 'id1'}
    this.dbClient.get.andReturn(Promise.resolve(doc))
    cut = doAction.getDoc
    cut(this.client, 'db1', 'id1').then((resp) =>
      expect(resp).toBe(doc)
      expect(this.client.use).toHaveBeenCalledWith('db1')
      expect(this.dbClient.get).toHaveBeenCalledWith('id1', 'promise')
      done()
    ).catch(done)

  it 'returns the existing doc object without hitting DB if docId is an object', (done) ->
    originalDoc = {_id: 'id1'}

    cut = doAction.getDoc
    cut(this.client, 'db1', originalDoc).then((doc) =>
      expect(this.dbClient.get).not.toHaveBeenCalled()
      expect(doc).toBe(originalDoc)
      done()
    ).catch(done)

  it 'returns a stub document with a unique ID if there is no docId', (done) ->
    cut = doAction.getDoc
    cut(this.client, 'db1').then((doc) =>
      expect(doc).toEqual({_id: 'new_uuid', audit: []})
      expect(this.client.getUuid).toHaveBeenCalledWith()
      done()
    ).catch(done)


describe 'getActionHandler', () ->
  beforeEach () ->
    this.doc = {_id: 'team_test', _rev: 'xxx', data: {a:'same'}, audit: []}
    this.stubDoc = {_id: 'new_uuid', audit: []}
    this.actions =
      team:
        success: (team, action, actor) ->
          team.data.a = 'modified'
        noop: (team, action, actor) ->
          team.data.a = 'same'
        error: (team, action, actor) ->
          throw ('error handler error')
      create: 
        create_team: (team, action, actor) ->
          team.data = {}

    this.action = {
      a: 'success',
      k: 'k',
      v: 'v',
    }

    this.getDocType = (doc) ->
      return 'team'

    this.getActionHandler = doAction.getActionHandler(this.actions, this.getDocType)

  it 'returns the actionHandler to handle the action as applied to the docType of the doc', () ->
    cut = this.getActionHandler
    actual = cut(this.doc, this.action)
    expect(actual).toBe(this.actions.team.success)

  it 'errors if no valid action', () ->
    cut = this.getActionHandler
    this.action.a = 'x'

    expect(() =>
      cut(this.doc, this.action)
    ).toThrow({ code : 403, body : {status:'error', msg: 'invalid action "x" for doc type "team".'} })

  it 'errors if it does not know how to handle the document type', () ->
    this.getDocType = (doc) -> return 'user'
    this.getActionHandler = doAction.getActionHandler(this.actions, this.getDocType)
    cut = this.getActionHandler

    expect(() =>
      cut(this.doc, this.action)
    ).toThrow({ code : 403, body : {status:'error', msg: 'invalid action "success" for doc type "user".'} })

  it 'gets a create handler if the doc is a stub', () ->
    cut = this.getActionHandler
    this.action.a = 'create_team'
    actual = cut(this.stubDoc, this.action)
    expect(actual).toEqual(this.actions.create.create_team)


describe 'runHandler', () ->
  it 'runs the handler', ->
    cut = doAction.runHandler

    actionHandler = jasmine.createSpy('actionHandler')

    cut(actionHandler, 'doc', 'action', 'actor')

    expect(actionHandler).toHaveBeenCalledWith('doc', 'action', 'actor')

  it 'reraises any errors thrown by actionHandler wrapped with a 500 error', () ->
    cut = doAction.runHandler

    errorMsg = 'actionHandler error msg'
    actionHandler = jasmine.createSpy('actionHandler').andCallFake(() -> throw errorMsg)

    expect(() -> 
      cut(actionHandler, 'doc', 'action', 'actor')
    ).toThrow({code: 500, body: {"status": "error", "msg": errorMsg}})


describe 'doAction', () ->
  beforeEach () ->
    this.doc = {_id: 'team_test', _rev: 'xxx', data: {a:'same'}, audit: []}
    this.newDoc = {_id: 'new_uuid', audit: []}
    this.actor = {name: 'user1'}
    spyOn(doAction, 'getUser').andReturn(Promise.resolve(this.actor))
    spyOn(doAction, 'getDoc').andReturn(Promise.resolve(this.doc))
    this.getActionHandler = jasmine.createSpy('getActionHandler').andReturn('actionHandler')
    spyOn(doAction, 'getActionHandler').andReturn(this.getActionHandler)
    spyOn(doAction, 'runHandler')
    this.validateDocUpdateFn = jasmine.createSpy('validateDocUpdateFn')
    spyOn(validate, 'validateDocUpdate').andReturn(this.validateDocUpdateFn)

    this.dbClient = {
      insert: jasmine.createSpy('insert').andReturn(Promise.resolve({result: 'from db'}))
    }
    this.client = {
      use: jasmine.createSpy('use').andReturn(this.dbClient)
    }
    this.couchUtils = {
      nano_user: jasmine.createSpy('nano_user').andReturn(this.client),
      conf: {COUCHDB: {SYSTEM_USER: 'systemUser'}},
    }

    this.actions =
      team:
        success: (team, action, actor) ->
          team.data.a = 'modified'
        noop: (team, action, actor) ->
          team.data.a = 'same'
        error: (team, action, actor) ->
          throw ('error handler error')
      create: 
        create_team: (team, action, actor) ->
          team.data = {}

    this.action = {
      a: 'success',
      k: 'k',
      v: 'v',
    }
    this.prepDoc = (doc) -> 
      doc.prepped = true
      return doc
    this.getDocType = (doc) ->
      return 'team'
    this.doAction = doAction.doAction(this.couchUtils, 'dbName', this.actions, 'validationFns', this.getDocType, null, 'shouldSkipValidationForUser')

  it 'sets up validateDocUpdate and getActionHandler', (done) ->
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      expect(doAction.getActionHandler).toHaveBeenCalledWith(this.actions, this.getDocType)
      expect(validate.validateDocUpdate).toHaveBeenCalledWith('validationFns', this.getDocType, 'shouldSkipValidationForUser')
      done()
    ).catch(done)

  it 'gets the doc and user, with a client bound to the actor', (done) ->
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      expect(this.couchUtils.nano_user).toHaveBeenCalledWith('user1')
      expect(doAction.getUser).toHaveBeenCalledWith(this.client, this.couchUtils.conf.COUCHDB.SYSTEM_USER, 'user1')
      expect(doAction.getDoc).toHaveBeenCalledWith(this.client, 'dbName', 'docId')
      done()
    ).catch(done)

  it 'gets the actionHandler and runs it', (done) ->
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      expect(this.getActionHandler).toHaveBeenCalledWith(this.doc, this.action)
      expect(doAction.runHandler).toHaveBeenCalledWith('actionHandler', this.doc, this.action, this.actor)
      done()
    ).catch(done)

  it 'does not save the doc if the doc has not changed', (done) ->
    doAction.runHandler.andCallFake((actionHandler, doc, action, actor) -> return)
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      expect(this.dbClient.insert).not.toHaveBeenCalled()
      done()
    ).catch(done)

  it 'saves any modifications to the doc made by the handler', (done) ->
    doAction.runHandler.andCallFake((actionHandler, doc, action, actor) -> doc.modified = true)
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      expect(this.dbClient.insert).toHaveBeenCalledWith(this.doc, 'promise')
      done()
    ).catch(done)

  it 'retries doAction if there is a 409 conflict', (done) ->
    doAction.runHandler.andCallFake((actionHandler, doc, action, actor) -> doc.modified = true)
    runCounter = 0
    this.dbClient.insert.andCallFake(() ->
      if runCounter++
        return Promise.resolve({result: 'from db'})
      else
        return Promise.reject({statusCode: 409})
    )
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      expect(doAction.getUser.calls.length).toBe(2)
      done()
    ).catch(done)

  it 'rethrows any non-409 couchdb errors', (done) ->
    doAction.runHandler.andCallFake((actionHandler, doc, action, actor) -> doc.modified = true)
    this.dbClient.insert.andReturn(Promise.reject({statusCode: 401}))
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      done('expect this.doAction to throw exception. None thrown.')
    ).catch((err) ->
      expect(err).toEqual({statusCode: 401})
      done()
    )


  it 'calls validateDocUpdate with the old and new doc and actor', (done) ->
    this.oldDoc = {_id: 'team_test', _rev: 'xxx', data: {a:'same'}, audit: []}
    doAction.runHandler.andCallFake((actionHandler, doc, action, actor) -> doc.modified = true)
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      expect(this.validateDocUpdateFn).toHaveBeenCalledWith(this.doc, this.oldDoc, this.actor)
      done()
    ).catch(done)


  it 'appends the action entry to audit, and adds user and datetime to entry', (done) ->
    doAction.runHandler.andCallFake((actionHandler, doc, action, actor) -> doc.modified = true)
    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      actual = this.doc
      entry = actual.audit[0]
      expect(entry.a).toEqual('success')
      expect(entry.k).toEqual('k')
      expect(entry.v).toEqual('v')
      expect(entry.u).toEqual('user1')
      expect(typeof entry.dt).toEqual('number')

      done()
    ).catch(done)


  it 'calls prepDoc with the document and the actor, if the prepDoc function exists', (done) ->
    spyOn(this, 'prepDoc').andReturn({prepped: true})
    this.doAction = doAction.doAction(this.couchUtils, 'dbName', this.actions, 'validationFns', this.getDocType, this.prepDoc, 'shouldSkipValidationForUser')

    cut = this.doAction

    cut('user1', 'docId', this.action).then(() =>
      expect(this.prepDoc).toHaveBeenCalledWith(this.doc, this.actor)
      done()
    ).catch(done)
