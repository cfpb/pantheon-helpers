middleware = require('../lib/middleware')

describe 'systemAuth', () ->
  beforeEach () ->
    this.conf = {
      COUCHDB: {SYSTEM_USER: 'admin'}
      COUCH_PWD: 'pwd'
      DEV: false
    }
    this.systemAuth = middleware.systemAuth(this.conf)

    spyOn(middleware.testing, 'basicAuth')
    this.basicAuth = middleware.testing.basicAuth
    this.next = jasmine.createSpy('next')
    this.req = {}

  it 'sets the system user on the session if successful basic auth authentication', () ->
    this.basicAuth.andReturn({name: 'admin', pass: 'pwd'})
    cut = this.systemAuth

    cut(this.req, 'resp', this.next)
    expect(this.basicAuth).toHaveBeenCalledWith(this.req)
    expect(this.req).toEqual({session: {user: 'admin'}})

  it 'calls next upon successful authentication', () ->
    this.basicAuth.andReturn({name: 'admin', pass: 'pwd'})
    cut = this.systemAuth
    cut(this.req, 'resp', this.next)
    expect(this.next).toHaveBeenCalled()

  it 'does not set the system user on the session if basic auth fails', () ->
    this.basicAuth.andReturn({name: 'admin', pass: 'wrong_pwd'})
    cut = this.systemAuth

    cut(this.req, 'resp', this.next)
    expect(this.basicAuth).toHaveBeenCalledWith(this.req)
    expect(this.req).toEqual({})

  it 'calls next upon unsuccessful authentication', () ->
    this.basicAuth.andReturn({name: 'admin', pass: 'wrong_pwd'})
    cut = this.systemAuth
    cut(this.req, 'resp', this.next)
    expect(this.next).toHaveBeenCalled()

  it 'always sets the system user on the session if conf.DEV is true', () ->
    this.conf.DEV = true
    this.basicAuth.andReturn({name: 'admin', pass: 'wrong_pwd'})
    cut = this.systemAuth
    cut(this.req, 'resp', this.next)
    expect(this.req).toEqual({session: {user: 'admin'}})

describe 'couch', () ->
  beforeEach () ->
    this.couchUtils = {
      nano_user: jasmine.createSpy('nano_user').andReturn('loggedInUserClient')
    }
    this.couch = middleware.couch(this.couchUtils)
    this.req = {session: {user: 'loggedInUser'}}
    this.next = jasmine.createSpy('next')

  it 'adds to the req a couch client bound to the logged in user', () ->
    cut = this.couch

    cut(this.req, 'resp', this.next)

    expect(this.couchUtils.nano_user).toHaveBeenCalledWith('loggedInUser')
    expect(this.req.couch).toEqual('loggedInUserClient')

  it 'calls next when done', () ->
    cut = this.couch

    cut(this.req, 'resp', this.next)

    expect(this.next).toHaveBeenCalled()

describe 'ensureAuthenticated', () ->
  it 'returns a 401 error if there is not a logged in user', () ->
    error = {error: "unauthorized", msg: "You are not logged in."}
    resp = {}
    resp.status = jasmine.createSpy('status').andReturn(resp)
    resp.end = jasmine.createSpy('end')

    req = {}

    cut = middleware.ensureAuthenticated

    cut(req, resp, 'next')

    expect(resp.status).toHaveBeenCalledWith(401)
    expect(resp.end).toHaveBeenCalledWith(JSON.stringify(error))


  it 'calls next if there is a logged in user', () ->
    req = {session: {user: 'loggedInUser'}}
    next = jasmine.createSpy('next')

    cut = middleware.ensureAuthenticated

    cut(req, 'resp', next)
    expect(next).toHaveBeenCalled()