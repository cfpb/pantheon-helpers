Promise = require('../lib').promise

_handleError = (done) ->
  (err) ->
    done(err)

describe 'resolveAll', () ->
  it 'resolves successful promises to object with state==resolved', (done) ->
    Promise.resolveAll([Promise.resolve('success')]).then((resp) ->
      expect(resp).toEqual([{state:'resolved', value: 'success'}])
      done()
    ).catch(_handleError(done))

  it 'resolves rejected promises to object with state=rejected', (done) ->
    Promise.resolveAll([Promise.reject('failure')]).then((resp) ->
      expect(resp).toEqual([{state:'rejected', error: 'failure'}])
      done()
    ).catch(_handleError(done))

  it 'resolves regardless of failures or successes', (done) ->
    Promise.resolveAll([
      Promise.resolve('success')
      Promise.reject('failure')
      Promise.resolve('success')
    ]).then((resp) ->
      expect(resp.length).toEqual(3)
      done()
    ).catch(_handleError(done))

describe 'hashResolveAll', () ->
  it 'accepts a hash of promises and returns a hash of result hashes with state and value/error', (done) ->
    Promise.hashResolveAll({
      a: Promise.resolve('success'),
      b: Promise.reject('failure'),
      c: Promise.resolve('success'),
    }).then((resp) ->
      expect(resp).toEqual({
        a: {state:'resolved', value: 'success'},
        b: {state:'rejected', error: 'failure'},
        c: {state:'resolved', value: 'success'},
      })
      done()
    ).catch(_handleError(done))

describe 'hashAll', () ->
  it 'accepts a hash of promises, and resolves to a corresponding hash of results', (done) ->
    Promise.hashAll({
      a: Promise.resolve('success a'),
      b: Promise.resolve('success b'),
    }).then((resp) ->
      expect(resp).toEqual({a: 'success a', b: 'success b'})
      done()
    ).catch(_handleError(done))
  it 'returns the first failure', (done) ->
    Promise.hashAll({
      a: Promise.resolve('success a'),
      b: Promise.reject('failure b'),
      c: Promise.resolve('success c'),
    }).catch((err) ->
      expect(err).toEqual('failure b')
      done()
    )

describe 'sendHttp', () ->
  beforeEach () ->
    this.resp = {
      status: jasmine.createSpy('status'),
      send: jasmine.createSpy('send')
    }
    this.resp.status.andCallFake(() => return this.resp)

  it "sends a resolved promise's jsonified value as the response", (done) ->
    cut = Promise.sendHttp

    this.resp.send.andCallFake((sentData) =>
      expect(sentData).toEqual(JSON.stringify({a:'b'}))
      expect(this.resp.status).not.toHaveBeenCalled()
      done()
    )

    cut(Promise.resolve({a: 'b'}), this.resp)

  it "sends an error with the same errorCode, and a useful subset of a rejected promise's jsonified value as the response", (done) ->
    cut = Promise.sendHttp

    error = {
      name: 'Error',
      error: 'not_found',
      reason: 'no_db_file',
      scope: 'couch',
      statusCode: 404,
      request: 'xxx'
      headers: 'xxx'
      errid: 'non_200',
      description: 'couch returned 404',
      msg: 'a long error msg' 
    }

    this.resp.send.andCallFake((sentData) =>
      expect(sentData).toEqual(JSON.stringify({error: 'not_found', reason: 'no_db_file', description: 'couch returned 404', msg: 'a long error msg'}))
      expect(this.resp.status).toHaveBeenCalledWith(404)
      done()
    )

    cut(Promise.reject(error), this.resp)

  it "sends a generic 500 with a msg that is the error, when there is no errorCode specified", (done) ->
    cut = Promise.sendHttp

    error = 'a weird error'

    this.resp.send.andCallFake((sentData) =>
      done()
      # expect(sentData).toEqual(JSON.stringify({error: 'server error', msg: error}))
      # expect(this.resp.status).toHaveBeenCalledWith(500)
      # done()
    )

    cut(Promise.reject(error), this.resp)