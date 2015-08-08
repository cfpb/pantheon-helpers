v = require('../lib/validateDocUpdate')

describe 'validateDocUpdate', () ->
  beforeEach () ->
    this.get_doc_type = jasmine.createSpy('get_doc_type').andReturn('team')
    this.should_skip_validation_for_user = jasmine.createSpy('should_skip_validation_for_user').andReturn(false)
    this.validation_fns = {
      team: {
        'u+': 'handle_u+'
        'u-': 'handle_u-'
      }
    }
    spyOn(v, 'getNewAuditEntries').andReturn(['entry', 'entry2'])
    spyOn(v, 'validateAuditEntries')
    this.validateDocUpdate = v.validateDocUpdate(this.validation_fns, this.get_doc_type, this.should_skip_validation_for_user)

  it 'gets the doc type from the passed get_doc_type fn', () ->
    this.validateDocUpdate('newDoc', 'oldDoc', 'actor')
    expect(this.get_doc_type).toHaveBeenCalledWith('oldDoc')

  it 'gets new audit entries from v.getNewAuditEntries', () ->
    this.validateDocUpdate('newDoc', 'oldDoc', 'actor')
    expect(v.getNewAuditEntries).toHaveBeenCalledWith('newDoc', 'oldDoc')

  it 'does not run validation if the should_skip_validation_for_user returns false for the actor (actor)', () ->
    this.should_skip_validation_for_user.andReturn(true)
    this.validateDocUpdate('newDoc', 'oldDoc', 'actor')
    expect(v.validateAuditEntries).not.toHaveBeenCalled()

  it 'does not run validation if there are no new audit entries', () ->
    v.getNewAuditEntries.andReturn([])
    this.validateDocUpdate('newDoc', 'oldDoc', 'actor')
    expect(v.validateAuditEntries).not.toHaveBeenCalled()

  it 'does not run validation if the document type is not in validation_fns', () ->
    this.get_doc_type.andReturn('not_a_handled_doc_type')
    this.validateDocUpdate('newDoc', 'oldDoc', 'actor')
    expect(v.validateAuditEntries).not.toHaveBeenCalled()

  it 'calls v.validateAuditEntries with the actions for the document type, the new audit entries, the actor and the old and new docs', () ->
    this.validateDocUpdate('newDoc', 'oldDoc', 'actor')
    expect(v.validateAuditEntries).toHaveBeenCalledWith(this.validation_fns.team, ['entry', 'entry2'], 'actor', 'oldDoc', 'newDoc')

  it 'does not require a should_skip_validation_for_user method; defaults to skipping nothing', () ->
    v.validateDocUpdate(this.validation_fns, this.get_doc_type)
    this.validateDocUpdate('newDoc', 'oldDoc', 'actor')
    expect(v.validateAuditEntries).toHaveBeenCalled()
 
describe 'getNewAuditEntries', () ->
  beforeEach () ->
    this.oldDoc = {audit: [1,2]}
    this.newDoc = {audit: [1,2,3,4]}

  it 'returns the audit entries created during this update', () ->
    actual = v.getNewAuditEntries(this.newDoc, this.oldDoc)
    expect(actual).toEqual([3,4])

  it 'returns all entries if there is no old doc (just created)', () ->
    actual = v.getNewAuditEntries(this.newDoc, null)
    expect(actual).toEqual([1,2,3,4])

  it 'throws an error if an old audit entry is modified when there is a new audit entry', () ->
    this.oldDoc.audit[1] = 3
    expect(() ->
      actual = v.getNewAuditEntries(this.newDoc, this.oldDoc)
    ).toThrow()

  it 'does not throw an error if an old audit entry is modified, but there are no new audit entries', () ->
      actual = v.getNewAuditEntries({audit: [1,2]}, {audit: [1,2]})
      expect(actual).toEqual([])

describe 'validateAuditEntries', () ->
  beforeEach () ->
    this.actions = {
      'u+': 'handle_u+'
      'u-': 'handle_u-'
    }
    spyOn(v, 'validateAuditEntry')
    this.entries = ['entry', 'entry2']

  it 'calls validateAuditEntry once for each entry', () ->
    v.validateAuditEntries(this.actions, this.entries, 'actor', 'oldDoc', 'newDoc')
    expect(v.validateAuditEntry.calls.length).toEqual(2)
    expect(v.validateAuditEntry.calls[0].args[1]).toEqual('entry')
    expect(v.validateAuditEntry.calls[1].args[1]).toEqual('entry2')

  it 'calls validateAuditEntry with the entries for the doctype, the entry, actor, and old/new docs', () ->
    v.validateAuditEntries(this.actions, this.entries, 'actor', 'oldDoc', 'newDoc')
    expect(v.validateAuditEntry).toHaveBeenCalledWith(this.actions, 'entry2', 'actor', 'oldDoc', 'newDoc')

describe 'validateAuditEntry', () ->
  beforeEach () ->
    this.actions = {
      'success': jasmine.createSpy('success').andReturn(true)
      'auth_fail': jasmine.createSpy('auth_fail').andCallFake(() -> throw({state: 'unauthorized', err: 'authorization error'}))
      'validation_fail': jasmine.createSpy('validation_fail').andCallFake(() -> throw({state: 'invalid', err: 'validation error'}))
    }
    this.entry = {
      u: 'user1',
      a: 'success',
    }
    this.actor = {
      name: 'user1'
    }

  it 'throws an error if the entry user is not the same as the actor', () ->
    this.actor.name = 'user2'
    expect(() =>
      v.validateAuditEntry(this.actions, this.entry, this.actor, 'oldDoc', 'newDoc')
    ).toThrow()

  it 'throws an error if the action type has no corresponding validation function in the actions', () ->
    this.entry.a = 'not_an_action'
    expect(() =>
      v.validateAuditEntry(this.actions, this.entry, this.actor, 'oldDoc', 'newDoc')
    ).toThrow()

  it 'does nothing if the validation passes', () ->
    v.validateAuditEntry(this.actions, this.entry, this.actor, 'oldDoc', 'newDoc')

  it 'throws an auth error if there is an auth failure', () ->
    this.entry.a = 'auth_fail'
    expect(() =>
      v.validateAuditEntry(this.actions, this.entry, this.actor, 'oldDoc', 'newDoc')
    ).toThrow({code: 401, body: 'authorization error'})

  it 'throws an invalid error if there is a validation failure', () ->
    this.entry.a = 'validation_fail'
    expect(() =>
      v.validateAuditEntry(this.actions, this.entry, this.actor, 'oldDoc', 'newDoc')
    ).toThrow({code: 403, body: 'validation error'})
