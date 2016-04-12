WebhookManager = require '../'

describe 'constructing the WebhookManager', ->
  describe 'when constructed without a datastore', ->
    it 'should throw an error', ->
      expect(=> new WebhookManager).to.throw '"datastore" is required'

  describe 'when constructed without a jobManager', ->
    it 'should throw an error', ->
      options = {datastore: {}}
      expect(=> new WebhookManager options).to.throw '"jobManager" is required'

  describe 'when constructed without a uuidAliasResolver', ->
    it 'should throw an error', ->
      options = {datastore: {}, jobManager: {}}
      expect(=> new WebhookManager options).to.throw '"uuidAliasResolver" is required'
