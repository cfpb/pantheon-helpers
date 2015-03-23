follow = require('follow')
worker = require('../lib/worker')
Promise = require('promise')

describe 'get_handlers', () ->

  resources = 
    rsrc1:
      team:
        'u+': '1u+'
        'u-': '1u-'
        self:
          'a+': '1sa+'
        other:
          'a+': '1oa+'
    rsrc2:
      team:
        'u+': '2u+'
        self:
          'a+': '2sa+'
        other:
          'a+': '2oa+'

  event = {
    a: 'u+',
    k: 'rsrc1',
  }
  it 'returns a matching handler for each resource', () ->
    event = {a: 'u+'}
    handlers = worker.get_handlers(resources, event, 'team')
    expect(handlers).toEqual({rsrc1: '1u+', rsrc2: '2u+'})

  it 'returns the self handler for the event resource and an other handler for all other resources', () ->
    event = {a: 'a+', k: 'rsrc1'}
    handlers = worker.get_handlers(resources, event, 'team')
    expect(handlers).toEqual({rsrc1: '1sa+', rsrc2: '2oa+'})

  it 'only returns handlers that exist', () ->
    event = {a: 'u-'}
    handlers = worker.get_handlers(resources, event, 'team')
    expect(handlers).toEqual({rsrc1: '1u-'})


describe 'get_unsynced_audit_entries', () ->
  it 'returns all audit entries that are unsynced', () ->
    doc = 
      audit:[
        {id: 'not-yet-synced'},
        {id: 'successfully-synced', synced: true},
        {id: 'failed-sync', synced: false},
      ]
      
    actual = worker.get_unsynced_audit_entries(doc)
    expect(actual).toEqual([
        {id: 'not-yet-synced'},
        {id: 'failed-sync', synced: false},
      ])

describe 'update_audit_entry_resource', () ->
  beforeEach () ->
    this.get_handler_data_path = jasmine.createSpy('get_handler_data_path').andReturn(['x', 'y'])
    this.doc = {x: {y: {existing_data: '93c50'}}}
    this.update_audit_entry_resource = worker.update_audit_entry_resource(this.doc, 'doc_type', this.get_handler_data_path)

  it 'gets the path for where to insert result from the handler from passed get_handler_data_path', () ->
    this.update_audit_entry_resource({state: 'resolved', value: {remote_id: 'f29a4'}}, 'rsrc')
    expect(this.get_handler_data_path).toHaveBeenCalledWith('doc_type', 'rsrc')

  it 'updates the object in document at path with returned data', () ->
    this.update_audit_entry_resource({state: 'resolved', value: {new_data: 'f29a4'}}, 'rsrc')
    expect(this.doc).toEqual({x: {y: {existing_data: '93c50', new_data: 'f29a4'}}})

  it 'does not update the document if there is no result', () ->
    this.update_audit_entry_resource({state: 'resolved', value: undefined}, 'rsrc')
    expect(this.doc).toEqual({x: {y: {existing_data: '93c50'}}})

describe 'update_audit_entry', () ->
  beforeEach () ->
    this.doc = 
      audit: [
        {id: '1', synced: true},
        {id: '2', synced: false},
        {id: '3'},
      ]
    this.update_audit_entry_resource_response = jasmine.createSpy('update_audit_entry_resource_response')
    spyOn(worker, 'update_audit_entry_resource').andReturn(this.update_audit_entry_resource_response)
    this.update_audit_entry = worker.update_audit_entry(this.doc, 'doc_type', 'get_handler_data_path')

  it 'sets synced to true if all handlers succeeded', () ->
    this.update_audit_entry({gh: {state: 'resolved'}, kratos: {state: 'resolved'}}, '2')
    expect(this.doc.audit[1].synced).toBe(true)
  it 'sets synced to false if any handlers failed, and entry sync had not previously succeeded', () ->
    this.update_audit_entry({gh: {state: 'resolved'}, kratos: {state: 'rejected'}}, '3')
    expect(this.doc.audit[2].synced).toBe(false)

  it 'does not set synced to false if entry sync had previously succeeded', () ->
    this.update_audit_entry({gh: {state: 'resolved'}, kratos: {state: 'rejected'}}, '1')
    expect(this.doc.audit[0].synced).toBe(true)

  it 'calls update_audit_entry_resource with doc, doc_type, get_handler_data_path', () ->
    this.update_audit_entry({gh: {state: 'resolved'}, kratos: {state: 'rejected'}}, '1')
    expect(worker.update_audit_entry_resource).toHaveBeenCalledWith(this.doc, 'doc_type', 'get_handler_data_path')

  it 'calls the function returned by update_audit_entry_resource once for each resource with a resource handler result and a resource', () ->
    this.update_audit_entry({gh: {state: 'resolved'}, kratos: {state: 'rejected'}}, '1')
    expect(this.update_audit_entry_resource_response.calls.length).toEqual(2)
    expect(this.update_audit_entry_resource_response.calls[0].args[0]).toEqual({state: 'resolved'})
    expect(this.update_audit_entry_resource_response.calls[0].args[1]).toEqual('gh')
    expect(this.update_audit_entry_resource_response.calls[1].args[1]).toEqual('kratos')


describe 'update_audit_entries', () ->

  beforeEach () ->
    that = this
    this.doc = {
      audit: [
        {id: '1', synced: true},
        {id: '2', synced: false},
        {id: '3'},
      ]
    }
    this.db = {
      get: (doc_id, callback) -> callback(null, that.doc)
      insert: (doc_id, callback) -> callback(null)
    }
    spyOn(this.db, 'get').andCallThrough()
    spyOn(this.db, 'insert').andCallThrough()
    this.update_audit_entry_response = jasmine.createSpy('update_audit_entry_response')
    spyOn(worker, 'update_audit_entry').andReturn(this.update_audit_entry_response)

    this.doc_type = 'team'
    this.handler_results = {
      '1': {gh: {state: 'resolved'}, kratos: {state: 'resolved'}},
      '2': {gh: {state: 'resolved'}, kratos: {state: 'rejected'}},
    }

  it 'gets the doc using the passed db and doc_id', (done) ->
    worker.update_audit_entries(this.db, 'doc_id', 'doc_type', this.handler_results, 'get_handler_data_path').then(() =>
      expect(this.db.get).toHaveBeenCalledWith('doc_id', jasmine.any(Function))
      return done()
    )

  it 'calls update_audit_entry with the doc, doc_type, and get_handler_data_path', (done) ->
    worker.update_audit_entries(this.db, 'doc_id', 'doc_type', this.handler_results, 'get_handler_data_path').then(() =>
      expect(worker.update_audit_entry).toHaveBeenCalledWith(this.doc, 'doc_type', 'get_handler_data_path')
      return done()
    ).catch((err) -> console.log('err', err))

  it 'calls the fn returned by update_audit_entry once for each entry with the entry_results ad teh entry_id', (done) ->
    worker.update_audit_entries(this.db, 'doc_id', 'doc_type', this.handler_results, 'get_handler_data_path').then(() =>
      expect(this.update_audit_entry_response.calls[0].args[0]).toBe(this.handler_results['1'])
      expect(this.update_audit_entry_response.calls[0].args[1]).toEqual('1')
      expect(this.update_audit_entry_response.calls[1].args[1]).toEqual('2')
      return done()
    ).catch((err) -> console.log('err', err))

  it 'saves the document if changes have been made', (done) ->
    this.update_audit_entry_response.andCallFake(() => this.doc.audit[1].synced = true)
    worker.update_audit_entries(this.db, 'doc_id', 'doc_type', this.handler_results, 'get_handler_data_path').then(() =>
      expect(this.db.insert).toHaveBeenCalledWith(this.doc, jasmine.any(Function))
      return done()
    ).catch((err) -> console.log('err', err))

  it 'does not save the document if changes have not been made', (done) ->
    worker.update_audit_entries(this.db, 'doc_id', 'doc_type', this.handler_results, 'get_handler_data_path').then(() =>
      expect(this.db.insert).not.toHaveBeenCalled()
      return done()
    ).catch((err) -> console.log('err', err))

describe 'on_change', () ->
  beforeEach () ->
    this.get_doc_type = jasmine.createSpy('get_doc_type').andReturn('doc_type')
    this.on_change = worker.on_change('db', 'handlers', 'get_handler_data_path', this.get_doc_type)

    this.gh_handler = jasmine.createSpy('gh_handler').andReturn(Promise.resolve({new_data: true}))
    this.kratos_handler = jasmine.createSpy('gh_handler').andReturn(Promise.reject())

    spyOn(worker, 'get_handlers').andReturn({gh: this.gh_handler, kratos: this.kratos_handler})
    spyOn(worker, 'get_unsynced_audit_entries').andReturn([{id: 'entry1'}, {id: 'entry2'}])
    spyOn(worker, 'update_audit_entries').andReturn(Promise.resolve())
    this.change = {doc: {_id: '123'}}

    this.expected_results =
      entry1:
        gh:
          {state: 'resolved', value: {new_data: true}}
        kratos:
          {state: 'rejected', error: undefined}
      entry2:
        gh:
          {state: 'resolved', value: {new_data: true}}
        kratos:
          {state: 'rejected', error: undefined}

  it 'gets unsynced audit entries from get_unsynced_audit_entries, passing in the doc from the change event', (done) ->
    this.on_change(this.change).then(() =>
      expect(worker.get_unsynced_audit_entries).toHaveBeenCalledWith(this.change.doc)
      done()
    )

  it 'gets the handlers for each unsynced entry by calling get_handlers with the resources, entry, and doc_type', (done) ->
    this.on_change(this.change).then(() =>
      expect(worker.get_handlers).toHaveBeenCalledWith('handlers', {'id': 'entry2'}, 'doc_type')
      done()
    )

  it 'calls each handler for each entry', (done) ->
    this.on_change(this.change).then(() =>
      expect(this.gh_handler.calls.length).toBe(2)
      expect(this.gh_handler.calls[0].args[0]).toEqual({id: 'entry1'})
      expect(this.gh_handler.calls[1].args[0]).toEqual({id: 'entry2'})
      expect(this.gh_handler.calls[0].args[1]).toBe(this.change.doc)

      expect(this.kratos_handler.calls.length).toBe(2)
      expect(this.kratos_handler.calls[0].args[0]).toEqual({id: 'entry1'})
      expect(this.kratos_handler.calls[1].args[0]).toEqual({id: 'entry2'})
      expect(this.kratos_handler.calls[0].args[1]).toBe(this.change.doc)

      done()
    )

  it 'formats all the responses from the handlers into a tree of hashes', (done) ->
    this.on_change(this.change).then(() =>
      expect(worker.update_audit_entries.calls[0].args[3]).toEqual(this.expected_results)
      done()
    )

  it 'calls update_audit_entries with the db, doc_id, doc_type, results, and get_handler_data_path', (done) ->
    this.on_change(this.change).then(() =>
      expect(worker.update_audit_entries).toHaveBeenCalledWith('db', this.change.doc._id, 'doc_type', this.expected_results, 'get_handler_data_path')
      done()
    )

describe 'start_worker', () ->
  beforeEach () ->
    this.db = {config: {url: 'url', db: 'db'}}
    this.feedFollow = jasmine.createSpy('feedFollow')
    this.feedOn = jasmine.createSpy('feedOn')
    spyOn(follow, 'Feed').andReturn({follow: this.feedFollow, on: this.feedOn})
    spyOn(worker, 'on_change').andReturn('on_change')

  it 'creates a new feed with opts from the passed nano db', () ->
    worker.start_worker(this.db, 'handlers', 'get_handler_data_path', 'get_doc_type')
    expect(follow.Feed).toHaveBeenCalledWith({db: 'url/db', include_docs: true})

  it 'attaches worker.on_change to the "change" event', () ->
    worker.start_worker(this.db, 'handlers', 'get_handler_data_path', 'get_doc_type')
    expect(worker.on_change).toHaveBeenCalledWith(this.db, 'handlers', 'get_handler_data_path', 'get_doc_type')
    expect(this.feedOn).toHaveBeenCalledWith('change', 'on_change')

  it 'starts following the feed', () ->
    worker.start_worker(this.db, 'handlers', 'get_handler_data_path', 'get_doc_type')
    expect(this.feedFollow).toHaveBeenCalled()

  it 'returns the feed', () ->
    actual = worker.start_worker(this.db, 'handlers', 'get_handler_data_path', 'get_doc_type')
    expect(actual.follow).toBeDefined()
