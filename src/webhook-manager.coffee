async = require 'async'
_     = require 'lodash'

class WebhookManager
  constructor: (options={}) ->
    {@datastore, @jobManager, @uuidAliasResolver} = options
    throw new Error '"datastore" is required' unless @datastore?
    throw new Error '"jobManager" is required' unless @jobManager?
    throw new Error '"uuidAliasResolver" is required' unless @uuidAliasResolver?

  enqueueForReceived: ({uuid, route, rawData, type}, callback) =>
    lastHop = _.last route
    return callback new Error('Missing last hop') unless lastHop?
    {from, to} = lastHop

    @_resolveUuids {from, to, uuid}, (error, results) =>
      return callback error if error?
      {from, to, uuid} = results
      return callback() unless from == to

      @_enqueue {uuid, route, rawData, type}, callback

  enqueueForSent: ({uuid, route, rawData, type}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @_enqueue {uuid, route, rawData, type}, callback

  _createRequest: (uuid, route, rawData, type, webhook, callback) =>
    @jobManager.createRequest 'request', {
      metadata:
        jobType: 'DeliverWebhook'
        auth:     {uuid}
        fromUuid: uuid
        toUuid:   uuid
        messageType: type
        route: route
        options: webhook
      rawData: rawData
    }, callback

  _enqueue: ({uuid, route, rawData, type}, callback) =>
    @datastore.findOne {uuid}, (error, device) =>
      return callback error if error?
      return callback new Error('Device not found') unless device?

      forwarders = _.get device.meshblu?.forwarders, type
      webhooks = _.filter forwarders, type: 'webhook'

      async.eachSeries webhooks, async.apply(@_createRequest, uuid, route, rawData, type), callback

  _resolveUuids: ({from, to, uuid}, callback) =>
    async.series {
      from: async.apply @uuidAliasResolver.resolve, from
      to:   async.apply @uuidAliasResolver.resolve, to
      uuid: async.apply @uuidAliasResolver.resolve, uuid
    }, callback

module.exports = WebhookManager
