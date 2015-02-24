require 'colors'
async = require 'async'
log = require('printit')
    prefix: 'application'
spawn = require('child_process').spawn
path = require 'path'

fs = require 'fs'
helpers = require './helpers'
VagrantManager = require('./vagrant').VagrantManager
vagrantManager = new VagrantManager()

Client = require("request-json").JsonClient
Client::configure = (url, password, callback) ->
    @host = url
    @post "login", password: password, (err, res, body) ->
        if err? or res.statusCode isnt 200
            log.error "Cannot get authenticated".red
        else
            callback()

class exports.ApplicationManager

    client: new Client ""

    checkError: (err, res, body, code, msg, callback) ->
        if err or res.statusCode isnt code
            log.error err.red if err?
            log.info msg
            if body?
                if body.msg?
                    log.info body.msg
                else
                    log.info body
        else
            callback()

    updateApp: (app, url, password, callback) ->
        log.info "Update #{app}..."
        @client.configure url, password, =>
            path = "api/applications/#{app}/update"
            @client.put path, {}, (err, res, body) =>
                output = 'Update failed.'.red
                @checkError err, res, body, 200, output, callback

    installApp: (app, url, repoUrl, password, callback) ->
        log.info "Install started for #{app}..."
        @client.configure url, password, =>
            app_descriptor =
                name: app
                git: repoUrl

            path = "api/applications/install"
            @client.post path, app_descriptor, (err, res, body) =>
                output = 'Install failed.'.red
                @checkError err, res, body, 201, output, callback

    uninstallApp: (app, url, password, callback) ->
        log.info "Uninstall started for #{app}..."
        @client.configure url, password, =>
            path = "api/applications/#{app}/uninstall"
            @client.del path, (err, res, body) =>
                output = 'Uninstall failed.'.red
                @checkError err, res, body, 200, output, callback

    stopApp: (app, callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', "cozy-monitor stop #{app}"]
            opts:
                'cwd': path.join __dirname, '..'
        helpers.spawnUntilEmpty cmds, callback

    startApp: (app, callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', "cozy-monitor start #{app}"]
            opts:
                'cwd': path.join __dirname, '..'
        helpers.spawnUntilEmpty cmds, callback

    checkStatus: (url, password, callback) ->
        checkApp = (app) =>
            (next) =>
                if app isnt "home" and app isnt "proxy"
                    path = "apps/#{app}/"
                else path = ""

                @client.get path, (err, res) ->
                    if err? or res.statusCode isnt 200
                        log.error "#{app}: " + "down".red
                    else
                        log.info "#{app}: " + "up".green
                    next()

        checkStatus = =>
            async.series [
                checkApp "home"
                checkApp "proxy", "routes"
            ], =>
                @client.get "api/applications/", (err, res, apps) ->
                    if err?
                        log.error err.red
                    else
                        funcs = []
                        if apps? and typeof apps is "object"
                            funcs.push checkApp(app.name) for app in apps.rows
                            async.series funcs, callback

        @client.configure url, password, checkStatus

    isInstalled: (app, url, password, callback) =>
        @client.configure url, password, =>
            @client.get "apps/#{app.toLowerCase()}/", (err, res, body) ->
                if body is "app unknown"
                    callback null, false
                else if err
                    callback err, false
                else
                    callback null, true

    addInDatabase: (manifest, callback) ->
        dsClient = new Client 'http://localhost:9101'
        dsClient.post 'data/', manifest, (err, res, body) ->
            callback err

    resetProxy: (callback) ->
        proxyClient = new Client 'http://localhost:9104'
        proxyClient.get 'routes/reset', (err, res, body) ->
            callback err

    removeFromDatabase: (manifest, callback) ->
        dsClient = new Client 'http://localhost:9101'
        option = key: manifest.slug
        dsClient.post 'request/application/byslug/', option, (err, res, body) ->
            return callback err if err? or not body?[0]?.value
            app = body[0].value
            port = app.port
            name = app.name
            dsClient.del "data/#{app._id}/", (err, res, body) ->
                callback err

    addPortForwarding: (name, port, callback) ->
        vagrantManager.getSshConfig (err, config) ->
            return callback err if err?
            # Start ssh process
            options=
                detached: true
                stdio: ['ignore', 'ignore', 'ignore']
            command = 'ssh'
            args = []
            args.push '-N'
            args.push 'vagrant@127.0.0.1'
            args.push '-R'
            args.push "#{port}:localhost:#{port}"
            args.push '-p'
            args.push config.Port
            args.push '-o'
            args.push "IdentityFile=#{config.IdentityFile}"
            args.push '-o'
            args.push "UserKnownHostsFile=#{config.UserKnownHostsFile}"
            args.push '-o'
            args.push "StrictHostKeyChecking=#{config.StrictHostKeyChecking}"
            args.push '-o'
            args.push "PasswordAuthentication=#{config.PasswordAuthentication}"
            args.push '-o'
            args.push "IdentitiesOnly=#{config.IdentitiesOnly}"

            child = spawn command, args, options
            # Retrieve pid
            pid = child.pid
            child.unref()
            # Store pid in pid file
            file = helpers.getPidFile(name)
            fs.open file, 'w', (err) ->
                return callback err if err?
                fs.writeFile file, pid, callback

    removePortForwarding: (name, port, callback) ->
        # Retrieve pid file
        file = helpers.getPidFile(name)
        if fs.existsSync file
            # Retrieve pid
            pid = fs.readFileSync file, 'utf8'
            # Remove pid file
            fs.unlink file
            try
                # Kill ssh process
                process.kill(pid)
            catch
                log.info 'No process.'
        callback()
