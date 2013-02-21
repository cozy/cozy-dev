require 'colors'
path = require 'path'
fs = require 'fs'
Client = require('request-json').JsonClient

helpers = require './helpers'

class exports.VagrantManager

    constructor: ->
        @baseBoxURL = 'https://www.cozycloud.cc/media/cozycloud-dev-latest.box'

    vagrantBoxAdd: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['box', 'add', @baseBoxURL]
        helpers.executeSynchronously cmds, ->
            console.log "The base box has been added to your environment".green
            callback()

    vagrantInit: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['init', "cozy-dev-#{@baseBoxVersion}"]
        helpers.executeSynchronously cmds, callback

    vagrantUp: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['up']
        helpers.executeSynchronously cmds, callback

    vagrantHalt: (callback)  ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['halt']
        helpers.executeSynchronously cmds, callback

    virtualMachineStatus: ->
        @isServiceUp "Data System", "localhost", 9101
        @isServiceUp "Cozy Proxy", "localhost", 9104
        @isServiceUp "Couchdb", "localhost", 5984
        @isServiceUp "Redis", "localhost", 6379

    isServiceUp: (service, domain, port) ->
        url = "http://#{domain}:#{port}"
        client = new Client url
        client.get '/', (err, res, body) ->
            result = if err is null then "OK".green else "KO".red
            console.log "#{service} at #{url}........." + result
