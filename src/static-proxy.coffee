httpProxy = require 'http-proxy'
http = require 'http'
https = require 'https'
send = require 'send'
path = require 'path'
url = require 'url'
{newClient} = require 'request-json-light'

log = require('printit')
    prefix: 'profixy\t'

APP =
    author: name: "test"
    comment: "community contribution"
    description: "test shell for app development"
    displayName: "Cozy Shell"
    git: "https://github.com/cozy-labs/cozy-browser-shell.git"
    icon: "main_icon.png"
    type: "static"
    name: 'cozy-proxified-app'
    slug: 'cozy-proxified-app'
    state: "installed"
    permissions: All: description: "Dev mode"

cookie = null
remoteCozy = null


loginRemote = (password, callback) ->
    log.info "LOGIN #{remoteCozy}"
    newClient(remoteCozy).post '/login', {password}, (err, res, body) ->
        err ?= body.error
        cookie = res?.headers?['set-cookie']
        cookie = cookie?.map((setter) -> setter.split(';')[0])
        cookie = cookie?.join '; '
        callback err

createApplication = (callback) ->
    urlpath = '/api/applications/install'
    options = headers: {cookie}

    log.info "CREATE APPLICATION #{APP.slug} on #{remoteCozy}"
    newClient(remoteCozy, options).post urlpath, APP, (err, res, body) ->
        err ?= new Error(body.message) if body.error
        callback err, body

ensureApplication = (callback) ->
    options = headers: {cookie}
    log.info "CHECK IF #{APP.slug} IS INSTALLED ON #{remoteCozy}"
    newClient(remoteCozy, options).get '/api/applications', (err, res, apps) ->
        return callback err if err
        for row in apps.rows
            if row.slug is APP.slug
                return callback null, row

        # if we get here, the application isnt installed.
        createApplication callback

prepareRemote = (password, callback)->
    loginRemote password, (err) ->
        return callback err if err
        ensureApplication (err, app) ->
            return callback err if err

            protocol = if remoteCozy.match /^https/ then https else http
            proxy = httpProxy.createServer
                target: remoteCozy,
                agent: protocol.globalAgent,
                headers:
                    host: url.parse(remoteCozy).host
                    cookie: cookie

            callback null, app, proxy

prepareLocal = ->
    throw new Error('not implemented yet')

startServer = (approot, proxy, callback) ->

    proxy.on 'error', (err) -> log.error err

    server = http.createServer (req, res) ->
        match = req.url.match(////apps/#{APP.slug}/(.*)///)
        if match?
            filepath = path.join approot, match[1] or 'index.html'
            log.info req.url, '->', filepath
            send(req, filepath).pipe res
        else
            proxy.web req, res

    port = process.env.PROXY_PORT or 3000

    server.listen port, (err) ->
        callback err, server, "http://localhost:#{port}/#apps/#{APP.slug}/"


module.exports.start = (approot, pkg, remote, password, callback = ->) ->

    log.info "SHELL FOR ", approot, "REMOTE = ", remote

    APP.name        = pkg.name
    APP.description = pkg.description
    APP.displayName = "#{pkg.displayName or pkg['cozy-displayName']} proxified"
    APP.name        = pkg.name
    APP.slug        = "#{pkg.name}-proxified"
    # APP.git         = pkg.repository.url

    tunnel = require('../misc/tunnel')
    tunnel.initialize ->

        if remote
            remoteCozy = remote
            prepareRemote password, (err, app, proxy) ->
                return log.error err if err
                startServer approot, proxy, callback
        else
            prepareLocal (err, app, proxy) ->
                return log.error err if err
                startServer approot, proxy, callback

module.exports.removeApplication = (callback) ->
    if remoteCozy and cookie
        options = headers: {cookie}
        urlpath = "/api/applications/#{APP.slug}/uninstall"
        newClient(remoteCozy, options).delete urlpath, callback
    else
        callback null
