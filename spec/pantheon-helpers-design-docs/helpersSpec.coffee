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
  this.helpers = helpers(this.shared)

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

    cut(this.getRow, this.start, this.send, (row) -> return row)

    expect(this.start).toHaveBeenCalledWith({
      headers: {
        'Content-Type': 'application/json'
      }
    })

  it 'returns a json serialized representation of data', () ->
    cut = this.helpers.sendNakedList

    cut(this.getRow, this.start, this.send, (row) -> return row)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(this.rows)

  it 'transforms each row according to the transformRow function', () ->
    cut = this.helpers.sendNakedList

    transformRow = (row) -> return row.doc
    cut(this.getRow, this.start, this.send, transformRow)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(this.rows.map(transformRow))

  it 'skips rows that throw a "skipped" string', () ->
    cut = this.helpers.sendNakedList

    transformRow = (row) ->
      if row.key % 2 then throw 'skip'
      return row
    cut(this.getRow, this.start, this.send, transformRow)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(_.filter(this.rows, (row) -> not (row.key % 2)))


describe 'get_prepped_of_type', () ->
  beforeEach () ->
    beforeEvery.apply(this)
    spyOn(this.helpers, 'sendNakedList')

  it 'delegates to sendNakedList', () ->
    cut = this.helpers.lists.get_prepped_of_type

    cut(this.getRow, this.start, this.send, 'team', 'header', 'req')

    expect(this.helpers.sendNakedList).toHaveBeenCalledWith(this.getRow, this.start, this.send, jasmine.any(Function))

  it 'passes a transformRow function that skips when not of matching type', () ->
    cut = this.helpers.lists.get_prepped_of_type

    cut(this.getRow, this.start, this.send, 'team', 'header', 'req')

    rowTransform = this.helpers.sendNakedList.calls[0].args[3]

    expect(() ->
      rowTransform({doc: {_id: 'user_4'}})
    ).toThrow('skip')

  it 'passes a transformRow function that preps docs that are of the matching type', () ->
    cut = this.helpers.lists.get_prepped_of_type

    cut(this.getRow, this.start, this.send, 'team', 'header', 'req')

    rowTransform = this.helpers.sendNakedList.calls[0].args[3]

    actual = rowTransform({doc: {_id: 'team_4'}})
    expect(actual).toEqual({_id: 'team_4', prepped: true})


describe 'lists.get_prepped', () ->
  beforeEach () ->
    beforeEvery.apply(this)
    spyOn(this.helpers, 'sendNakedList')

  it 'delegates to sendNakedList', () ->
    cut = this.helpers.lists.get_prepped

    cut(this.getRow, this.start, this.send, 'header', 'req')

    expect(this.helpers.sendNakedList).toHaveBeenCalledWith(this.getRow, this.start, this.send, jasmine.any(Function))

  it 'passes a transformRow function that preps docs', () ->
    cut = this.helpers.lists.get_prepped

    cut(this.getRow, this.start, this.send, 'header', 'req')

    rowTransform = this.helpers.sendNakedList.calls[0].args[3]

    actual = rowTransform({doc: {_id: 'team_4'}})
    expect(actual).toEqual({_id: 'team_4', prepped: true})


describe 'lists.get_values', () ->
  beforeEach () ->
    beforeEvery.apply(this)
    spyOn(this.helpers, 'sendNakedList')

  it 'delegates to sendNakedList', () ->
    cut = this.helpers.lists.get_values

    cut(this.getRow, this.start, this.send, 'header', 'req')

    expect(this.helpers.sendNakedList).toHaveBeenCalledWith(this.getRow, this.start, this.send, jasmine.any(Function))

  it 'passes a transformRow function that returns the row value', () ->
    this.helpers.lists.get_values('header', 'req')

    rowTransform = this.helpers.sendNakedList.calls[0].args[3]

    actual = rowTransform({doc: {_id: 'team_4'}, value: 'a'})
    expect(actual).toEqual('a')


describe 'lists.get_first_prepped', () ->
  beforeEach beforeEvery

  it 'gets the first row and returns the result properly formed and prepped', () ->
    

    cut = this.helpers.lists.get_first_prepped
    actual = cut(this.getRow, this.start, this.send)

    expect(this.getRow.calls.length).toEqual(1)
    expect(this.start).toHaveBeenCalledWith({
      headers: {
        'Content-Type': "application/json"
      }
    })
    expect(JSON.parse(this.sent).prepped).toBe(true)

  it 'throws a 404 error if there are no rows', () ->
    this.getRow.andReturn(undefined)

    cut = this.helpers.lists.get_first_prepped

    expect(() =>
      cut(this.getRow, this.start, this.send, 'req', 'resp')
    ).toThrow(['error', 'not_found', 'document matching query does not exist'])


describe 'shows.get_prepped', () ->
  beforeEach beforeEvery

  it 'returns the prepared doc, as a json response', () ->
    cut = this.helpers.shows.get_prepped

    actual = cut({_id: 'team_4'}, 'req')

    expect(JSON.parse(actual.body).prepped).toBe(true)

