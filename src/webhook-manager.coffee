async = require 'async'
_     = require 'lodash'

class WebhookManager
  constructor: (options={}) ->
    {@datastore, @jobManager, @uuidAliasResolver} = options
    throw new Error '"datastore" is required' unless @datastore?
    throw new Error '"jobManager" is required' unless @jobManager?
    throw new Error '"uuidAliasResolver" is required' unless @uuidAliasResolver?

  enqueueForReceived: ({forwardedRoutes, type, rawData, route, uuid}, callback) =>
    lastHop = _.last route
    return callback new Error('Missing last hop') unless lastHop?
    {from, to} = lastHop

    @_resolveUuids {from, to, uuid}, (error, results) =>
      return callback error if error?
      {from, to, uuid} = results
      return callback() unless from == to
      @_enqueue {forwardedRoutes, type, rawData, route, uuid}, callback

  enqueueForSent: ({forwardedRoutes, type, rawData, route, uuid}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @_enqueue {forwardedRoutes, type, rawData, route, uuid}, callback

  _createRequest: ({forwardedRoutes, type, rawData, route, uuid}, webhook, callback) =>
    @jobManager.createRequest 'request', {
      metadata:
        jobType: 'DeliverWebhook'
        auth:     {uuid}
        fromUuid: uuid
        toUuid:   uuid
        messageType: type
        route: route
        forwardedRoutes: forwardedRoutes
        options: webhook
      rawData: rawData
    }, callback

  _enqueue: ({forwardedRoutes, type, rawData, route, uuid}, callback) =>
    projection =
      uuid: true
      'meshblu.forwarders': true
    @datastore.findOne {uuid}, projection, (error, device) =>
      return callback error if error?
      return callback new Error('Device not found') unless device?

      forwarders = _.get device.meshblu?.forwarders, type
      webhooks = _.filter forwarders, type: 'webhook'

      createRequest = async.apply @_createRequest, {forwardedRoutes, type, rawData, route, uuid}
      async.eachSeries webhooks, createRequest, callback

  _resolveUuids: ({from, to, uuid}, callback) =>
    async.series {
      from: async.apply @uuidAliasResolver.resolve, from
      to:   async.apply @uuidAliasResolver.resolve, to
      uuid: async.apply @uuidAliasResolver.resolve, uuid
    }, callback

module.exports = WebhookManager
