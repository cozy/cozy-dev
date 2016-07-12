httpProxy = require('http-proxy')
http = require 'http'
https = require 'https'
send = require 'send'
path = require 'path'
url = require 'url'
{newClient} = require 'request-json-light'

BENCH_SLUG = 'cozybrowserbench'
cookie = null
remoteCozy = null


loginRemote = (password, callback) ->
    console.log "LOGIN #{remoteCozy}"
    newClient(remoteCozy).post '/login', {password}, (err, res, body) ->
        err ?= body.error
        cookie = res?.headers?['set-cookie']
        cookie = cookie?.map((setter) -> setter.split(';')[0])
        cookie = cookie?.join '; '
        callback err

createApplication = (callback) ->
    urlpath = '/api/applications/install'
    options = headers: {cookie}
    app = {
        author: name: "test"
        comment: "community contribution"
        description: "test shell for app development"
        displayName: "Cozy Shell"
        git: "https://github.com/cozy-labs/cozy-browser-shell.git"
        icon: "main_icon.png"
        type: "static"
        name: BENCH_SLUG
        slug: BENCH_SLUG
        state: "installed"
        permissions: All: description: "Dev mode"
    }

    console.log "CREATE APPLICATION #{BENCH_SLUG} on #{remoteCozy}"
    newClient(remoteCozy, options).post urlpath, app, (err, res, body) ->
        err ?= new Error(body.message) if body.error
        callback err, body

ensureApplication = (callback) ->
    options = headers: {cookie}
    console.log "CHECK IF #{BENCH_SLUG} IS INSTALLED ON #{remoteCozy}"
    newClient(remoteCozy, options).get '/api/applications', (err, res, apps) ->
        return callback err if err
        exists = apps.rows.find (app) -> app.slug is BENCH_SLUG
        if exists
            callback null, exists
        else
            createApplication callback

prepareRemote = (password, callback)->
    loginRemote password, (err) ->
        return callback err if err
        ensureApplication (err, app) ->
            return callback err if err

            proxy = httpProxy.createServer
                target: remoteCozy,
                agent: https.globalAgent,
                headers:
                    host: url.parse(remoteCozy).host
                    cookie: cookie

            callback null, app, proxy

prepareLocal = ->
    throw new Error('not implemented yet')

startServer = (approot, proxy, callback) ->

    proxy.on 'error', (err) -> console.log err

    server = http.createServer (req, res) ->
        match = req.url.match(////apps/#{BENCH_SLUG}/(.*)///)
        if match?
            filepath = path.join approot, match[1] or 'index.html'
            console.log req.url, '->', filepath
            send(req, filepath).pipe res
        else
            proxy.web req, res

    port = process.env.BENCH_PORT or 3000

    server.listen port, (err) ->
        callback err, server, "http://localhost:#{port}/#apps/#{BENCH_SLUG}/"


module.exports.start = (approot, remote, password, callback = ->) ->

    console.log "SHELL FOR ", approot, "REMOTE = ", remote
    tunnel = require('../misc/tunnel')
    tunnel.initialize ->

        if remote
            remoteCozy = remote
            prepareRemote password, (err, app, proxy) ->
                return console.log err if err
                startServer approot, proxy, callback
        else
            prepareLocal (err, app, proxy) ->
                return console.log err if err
                startServer approot, proxy, callback

module.exports.removeApplication = (callback) ->
    if remoteCozy and cookie
        options = headers: {cookie}
        urlpath = "/api/applications/#{BENCH_SLUG}/uninstall"
        newClient(remoteCozy, options).delete urlpath, callback
    else
        callback null
