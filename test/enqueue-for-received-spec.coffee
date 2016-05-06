Datastore      = require 'meshblu-core-datastore'
JobManager     = require 'meshblu-core-job-manager'
mongojs        = require 'mongojs'
redis          = require 'fakeredis'
RedisNS        = require '@octoblu/redis-ns'
uuid           = require 'uuid'
{beforeEach, describe, it, sinon} = global
{expect} = require 'chai'
WebhookManager = require '../'

describe '->enqueueForReceived', ->
  beforeEach (done) ->
    database = mongojs 'meshblu-core-manager-webhook', ['devices']
    @datastore = new Datastore
      database: database
      collection: 'devices'

    database.devices.remove done

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
              received: [{
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

        @sut.enqueueForReceived {
          uuid: 'uuid'
          route: [{type: 'message.received', to: 'to', from: 'from'}]
          forwardedRoutes: []
          rawData: '{}'
          type: 'message.received'
        }, done

      it 'should not enqueue a job to deliver the webhook', (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          expect(request).not.to.exist
          done()

    describe 'when called with two aliases that match', ->
      beforeEach (done) ->
        @uuidAliasResolver.resolve.withArgs('from').yields null, 'uuid'
        @uuidAliasResolver.resolve.withArgs('to').yields null, 'uuid'
        @uuidAliasResolver.resolve.withArgs('uuid').yields null, 'uuid'

        @sut.enqueueForReceived {
          uuid: 'uuid'
          route: [{type: 'message.received', to: 'to', from: 'from'}]
          forwardedRoutes: []
          rawData: '{}'
          type: 'message.received'
        }, done

      it 'should enqueue a job to deliver the webhook', (done) ->
        @jobManager.getRequest ['request'], (error, request) =>
          return done error if error?
          expect(request).to.containSubset {
            metadata:
              jobType: 'DeliverWebhook'
              auth:
                uuid: 'uuid'
              fromUuid: 'uuid'
              toUuid: 'uuid'
              messageType: 'message.received'
              route: [{type: "message.received", from: "from", to: "to"}]
              forwardedRoutes: []
              options:
                type:   'webhook'
                url:    'https://google.com'
                method: 'POST'
            rawData: '{}'
          }
          done()
