Datastore      = require 'meshblu-core-datastore'
JobManager     = require 'meshblu-core-job-manager'
mongojs        = require 'mongojs'
redis          = require 'fakeredis'
RedisNS        = require '@octoblu/redis-ns'
uuid           = require 'uuid'
WebhookManager = require '../'

describe '->enqueueForSent', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: mongojs('meshblu-core-manager-webhook')
      collection: 'devices'

    @datastore.remove done

  beforeEach ->
    @redisKey = uuid.v1()
    @jobManager = new JobManager
      client: new RedisNS 'ns', redis.createClient(@redisKey)
      timeoutSeconds: 1

  beforeEach ->
    client = new RedisNS 'ns', redis.createClient(@redisKey)
    jobManager = new JobManager {client: client, timeoutSeconds: 1}

    @uuidAliasResolver = {resolve: sinon.stub()}
    @sut = new WebhookManager {@datastore, jobManager, @uuidAliasResolver}

  describe 'when the device has one webhooks', ->
    beforeEach (done) ->
      @datastore.insert {
        uuid: 'uuid'
        meshblu:
          forwarders:
            message:
              sent: [{
                type:   'webhook'
                url:    'https://google.com'
                method: 'POST'
              }]
      }, done

    describe 'when called with two aliases that dont match', ->
      beforeEach (done) ->
        @uuidAliasResolver.resolve.withArgs('from').yields null, 'from'
        @uuidAliasResolver.resolve.withArgs('to').yields null, 'uuid'
        @uuidAliasResolver.resolve.withArgs('uuid').yields null, 'uuid'

        @sut.enqueueForSent {
          uuid: 'uuid'
          route: [{type: 'message.sent', to: 'to', from: 'from'}]
          rawData: '{}'
          type: 'message.sent'
        }, done

      it 'should enqueue a job to deliver the webhook', (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          delete request?.metadata?.responseId
          expect(request).to.deep.equal {
            metadata:
              jobType: 'DeliverWebhook'
              auth:
                uuid: 'uuid'
              fromUuid: 'uuid'
              toUuid: 'uuid'
              messageType: 'message.sent'
              route: [{type: "message.sent", from: "from", to: "to"}]
              options:
                type:   'webhook'
                url:    'https://google.com'
                method: 'POST'
            rawData: '{}'
          }
          done()

    describe 'when called with two aliases that match', ->
      beforeEach (done) ->
        @uuidAliasResolver.resolve.withArgs('from').yields null, 'uuid'
        @uuidAliasResolver.resolve.withArgs('to').yields null, 'uuid'
        @uuidAliasResolver.resolve.withArgs('uuid').yields null, 'uuid'

        @sut.enqueueForSent {
          uuid: 'uuid'
          route: [{type: 'message.sent', to: 'to', from: 'from'}]
          rawData: '{}'
          type: 'message.sent'
        }, done

      it 'should enqueue a job to deliver the webhook', (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          delete request?.metadata?.responseId
          expect(request).to.deep.equal {
            metadata:
              jobType: 'DeliverWebhook'
              auth:
                uuid: 'uuid'
              fromUuid: 'uuid'
              toUuid: 'uuid'
              messageType: 'message.sent'
              route: [{type: "message.sent", from: "from", to: "to"}]
              options:
                type:   'webhook'
                url:    'https://google.com'
                method: 'POST'
            rawData: '{}'
          }
          done()
