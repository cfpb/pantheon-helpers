helpers = require('../../lib/pantheon-helpers-design-docs/helpers')
_ = require('underscore')

beforeEvery = () ->
  this.sent = ''
  this.send = jasmine.createSpy('send').andCallFake((data) => this.sent += data)
  this.start = jasmine.createSpy('start')
  pointer = 0
  this.rows = [
    {doc: {_id: 'team_1', body: 'a'}, key: 1, value: 'a'},
    {doc: {_id: 'user_2', body: 'b'}, key: 2, value: 'b'},
    {doc: {_id: 'team_3', body: 'c'}, key: 3, value: 'c'},
    {doc: {_id: 'user_4', body: 'd'}, key: 4, value: 'd'},
  ]
  this.getRow = jasmine.createSpy('getRow').andCallFake(() => return this.rows[pointer++])
  this.shared = {
    getDocType: jasmine.createSpy('getDocType').andCallFake((doc) -> return doc._id.split('_')[0])
    prepDoc: jasmine.createSpy('prepDoc').andCallFake((doc) -> doc.prepped=true; return doc)
  }
  this.helpers = helpers(this.shared, this.getRow, this.start, this.send)

describe 'JSONResponse', () ->
  beforeEach beforeEvery

  it 'takes a document and formats it for CouchDB as a proper JSON response', () ->
    
    cut = this.helpers.JSONResponse

    doc = {a: 'b'}
    
    actual = cut(doc)

    expect(actual).toEqual({
      headers: {
        'Content-Type': "application/json"
      }
      body: JSON.stringify(doc),
    })

describe 'sendNakedList', () ->
  beforeEach beforeEvery

  it 'sends a proper header', () ->
    cut = this.helpers.sendNakedList

    cut((row) -> return row)

    expect(this.start).toHaveBeenCalledWith({
      headers: {
        'Content-Type': 'application/json'
      }
    })

  it 'returns a json serialized representation of data', () ->
    cut = this.helpers.sendNakedList

    cut((row) -> return row)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(this.rows)

  it 'transforms each row according to the transformRow function', () ->
    cut = this.helpers.sendNakedList

    transformRow = (row) -> return row.doc
    cut(transformRow)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(this.rows.map(transformRow))

  it 'skips rows that throw a "skipped" string', () ->
    cut = this.helpers.sendNakedList

    transformRow = (row) ->
      if row.key % 2 then throw 'skip'
      return row
    cut(transformRow)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(_.filter(this.rows, (row) -> not (row.key % 2)))


describe 'get_prepped_of_type', () ->
  beforeEach () ->
    beforeEvery.apply(this)
    spyOn(this.helpers, 'sendNakedList')

  it 'returns a couchdb list function', () ->
    cut = this.helpers.listGenerators.get_prepped_of_type
    actual = cut('team')

    expect(actual).toEqual(jasmine.any(Function))

  it 'delegates to sendNakedList', () ->
    cut = this.helpers.listGenerators.get_prepped_of_type

    cut('team')('header', 'req')

    expect(this.helpers.sendNakedList).toHaveBeenCalled()

  it 'passes a transformRow function that skips when not of matching type', () ->
    cut = this.helpers.listGenerators.get_prepped_of_type('team')('header', 'req')
    rowTransform = this.helpers.sendNakedList.calls[0].args[0]

    expect(() ->
      rowTransform({doc: {_id: 'user_4'}})
    ).toThrow('skip')

  it 'passes a transformRow function that preps docs that are of the matching type', () ->
    cut = this.helpers.listGenerators.get_prepped_of_type('team')('header', 'req')
    rowTransform = this.helpers.sendNakedList.calls[0].args[0]

    actual = rowTransform({doc: {_id: 'team_4'}})
    expect(actual).toEqual({_id: 'team_4', prepped: true})


describe 'lists.get_prepped', () ->
  beforeEach () ->
    beforeEvery.apply(this)
    spyOn(this.helpers, 'sendNakedList')

  it 'delegates to sendNakedList', () ->
    cut = this.helpers.lists.get_prepped

    cut('header', 'req')

    expect(this.helpers.sendNakedList).toHaveBeenCalled()

  it 'passes a transformRow function that preps docs', () ->
    this.helpers.lists.get_prepped('header', 'req')

    rowTransform = this.helpers.sendNakedList.calls[0].args[0]

    actual = rowTransform({doc: {_id: 'team_4'}})
    expect(actual).toEqual({_id: 'team_4', prepped: true})


describe 'lists.get_values', () ->
  beforeEach () ->
    beforeEvery.apply(this)
    spyOn(this.helpers, 'sendNakedList')

  it 'delegates to sendNakedList', () ->
    cut = this.helpers.lists.get_values

    cut('header', 'req')

    expect(this.helpers.sendNakedList).toHaveBeenCalled()

  it 'passes a transformRow function that returns the row value', () ->
    this.helpers.lists.get_values('header', 'req')

    rowTransform = this.helpers.sendNakedList.calls[0].args[0]

    actual = rowTransform({doc: {_id: 'team_4'}, value: 'a'})
    expect(actual).toEqual('a')


describe 'lists.get_first_prepped', () ->
  beforeEach beforeEvery

  it 'gets the first row and returns the result from sending it through shows.get_prepped', () ->
    spyOn(this.helpers.shows, 'get_prepped').andReturn('prepped')

    cut = this.helpers.lists.get_first_prepped
    actual = cut()

    expect(this.getRow.calls.length).toEqual(1)
    expect(this.helpers.shows.get_prepped).toHaveBeenCalledWith(this.rows[0].doc)
    expect(actual).toEqual('prepped')

  it 'throws a 404 error if there are no rows', () ->
    this.getRow.andReturn(undefined)

    cut = this.helpers.lists.get_first_prepped

    expect(cut).toThrow(['error', 'not_found', 'document matching query does not exist'])


describe 'shows.get_prepped', () ->
  beforeEach beforeEvery

  it 'returns the prepared doc, as a json response', () ->
    cut = this.helpers.shows.get_prepped

    actual = cut({_id: 'team_4'}, 'req')

    expect(JSON.parse(actual.body).prepped).toBe(true)

