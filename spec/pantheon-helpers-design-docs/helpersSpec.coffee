h = require('../../lib/pantheon-helpers-design-docs/helpers')
_ = require('underscore')


describe 'JSONResponse', () ->
  it 'takes a document and formats it for CouchDB as a proper JSON response', () ->
    cut = h.JSONResponse

    doc = {a: 'b'}
    
    actual = cut(doc)

    expect(actual).toEqual({
      headers: {
        'Content-Type': "application/json"
      }
      body: JSON.stringify(doc),
    })

beforeEachListShow = () ->
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
  h.shared = this.shared

describe 'sendNakedList', () ->
  beforeEach beforeEachListShow

  it 'sends a proper header', () ->
    cut = h.sendNakedList

    cut(this.getRow, this.start, this.send, (row) -> return row)

    expect(this.start).toHaveBeenCalledWith({
      headers: {
        'Content-Type': 'application/json'
      }
    })

  it 'returns a json serialized representation of data', () ->
    cut = h.sendNakedList

    cut(this.getRow, this.start, this.send, (row) -> return row)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(this.rows)

  it 'transforms each row according to the transformRow function', () ->
    cut = h.sendNakedList

    transformRow = (row) -> return row.doc
    cut(this.getRow, this.start, this.send, transformRow)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(this.rows.map(transformRow))

  it 'skips rows that throw a "skipped" string', () ->
    cut = h.sendNakedList

    transformRow = (row) ->
      if row.key % 2 then throw 'skip'
      return row
    cut(this.getRow, this.start, this.send, transformRow)

    actual = JSON.parse(this.sent)
    expect(actual).toEqual(_.filter(this.rows, (row) -> not (row.key % 2)))

describe 'get_prepped_of_type', () ->
  beforeEach () ->
    beforeEachListShow.apply(this)
    spyOn(h, 'sendNakedList')

  it 'returns a couchdb list function', () ->
    cut = h.listGenerators.get_prepped_of_type
    actual = cut('team')

    expect(actual).toEqual(jasmine.any(Function))

  it 'delegates to sendNakedList', () ->
    cut = h.listGenerators.get_prepped_of_type

    cut('team')('header', 'req')

    expect(h.sendNakedList).toHaveBeenCalled()

  it 'passes a transformRow function that skips when not of matching type', () ->
    cut = h.listGenerators.get_prepped_of_type('team')('header', 'req')
    rowTransform = h.sendNakedList.calls[0].args[3]

    expect(() ->
      rowTransform({doc: {_id: 'user_4'}})
    ).toThrow('skip')

  it 'passes a transformRow function that preps docs that are of the matching type', () ->
    cut = h.listGenerators.get_prepped_of_type('team')('header', 'req')
    rowTransform = h.sendNakedList.calls[0].args[3]

    actual = rowTransform({doc: {_id: 'team_4'}})
    expect(actual).toEqual({_id: 'team_4', prepped: true})

describe 'lists.get_prepped', () ->
  beforeEach () ->
    beforeEachListShow.apply(this)
    spyOn(h, 'sendNakedList')

  it 'delegates to sendNakedList', () ->
    cut = h.lists.get_prepped

    cut('header', 'req')

    expect(h.sendNakedList).toHaveBeenCalled()

  it 'passes a transformRow function that preps docs', () ->
    h.lists.get_prepped('header', 'req')

    rowTransform = h.sendNakedList.calls[0].args[3]

    actual = rowTransform({doc: {_id: 'team_4'}})
    expect(actual).toEqual({_id: 'team_4', prepped: true})

describe 'lists.get_values', () ->
  beforeEach () ->
    beforeEachListShow.apply(this)
    spyOn(h, 'sendNakedList')

  it 'delegates to sendNakedList', () ->
    cut = h.lists.get_values

    cut('header', 'req')

    expect(h.sendNakedList).toHaveBeenCalled()

  it 'passes a transformRow function that returns the row value', () ->
    h.lists.get_values('header', 'req')

    rowTransform = h.sendNakedList.calls[0].args[3]

    actual = rowTransform({doc: {_id: 'team_4'}, value: 'a'})
    expect(actual).toEqual('a')

describe 'shows.get_prepped', () ->
  beforeEach () ->
    beforeEachListShow.apply(this)

  it 'returns the prepared doc, as a json response', () ->
    cut = h.shows.get_prepped

    actual = cut({_id: 'team_4'}, 'req')

    expect(JSON.parse(actual.body).prepped).toBe(true)

