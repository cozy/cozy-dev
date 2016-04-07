require 'colors'

async = require 'async'
path = require 'path'
fs = require 'fs'
pp = require 'parentpath'
{spawn, exec} = require 'child_process'
semver = require 'semver'

log = require('printit')
    prefix: 'application'
Client = require('request-json').JsonClient

helpers = require './helpers'
VagrantManager = require('./vagrant').VagrantManager
vagrantManager = new VagrantManager()


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
        helpers.spawnUntilEmpty cmds, callback


    startApp: (app, callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', "cozy-monitor start #{app}"]
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
            return callback err if err?
            if manifest.iconPath?
                iconPath = "data/#{body._id}/attachments/"
                data = name: "icon.#{manifest.iconType}"
                filePath = manifest.iconPath
                dsClient.sendFile iconPath, filePath, data, (err, res, body) ->
                    callback err
            else
                callback()


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


    # Factory for configuration, regarding if the app is `static` or not
    configLocalApp: (action, app, callback) ->
        suffix = if app.type is 'static' then 'StaticPath' else 'PortForwarding'
        method = "#{action}#{suffix}"
        if action is 'add'
            @[method](app.name, app.port, callback)
        else
            @[method](app.name, callback)


    # Add port forward from host to virtual box for application <name>
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


    # Link the app from vagrant synced_folder to app `path`
    addStaticPath: (name, appPath, callback) ->
        pp 'Vagrantfile', (dir) ->
            appPath = "/vagrant/#{path.relative(dir, path.resolve(appPath))}"
            srvPath = "/srv/#{name.toLowerCase()}"

            cmd = "vagrant ssh --command 'sudo ln -sf #{appPath} #{srvPath}'"
            exec cmd, callback


    # Remove port forward from host to virtual box for application <name>
    removePortForwarding: (name, callback) ->
        # Retrieve pid file
        file = helpers.getPidFile(name)
        if fs.existsSync file
            # Retrieve pid
            pid = fs.readFileSync file, 'utf8'
            # Remove pid file
            fs.unlink file
            try
                # Kill ssh process
                process.kill pid
            catch
                log.info 'No process.'
        callback()


    removeStaticPath: (name, callback) ->
        cmd = "vagrant ssh --command 'sudo rm -f /srv/#{name.toLowerCase()}'"
        exec cmd, callback


    # Check stack versions
    stackVersions: (callback) ->

        # Recover all stack application in database.
        dsClient = new Client 'http://localhost:9101'
        dsClient.post 'request/stackapplication/all/', {}, (err, res, body) ->
            return callback() unless body and not err?
            async.eachSeries body, (app, cb) ->
                app = app.value
                # Check version with version stored in package.json
                path = "cozy/cozy-#{app.name}/master/package.json"
                github = new Client 'https://raw.github.com/'
                github.get path, (err, res, data) ->
                    if err? and err.code is 'ENOTFOUND'
                        log.warn "You're in offline, can't check cozy stack versions."
                        callback()
                    else if data?.version?
                        if semver.gt(data.version, app.version)
                            log.warn "#{app.name}: "
                            log.warn "#{app.version} -> #{data.version}"
                            cb true
                        else
                            cb false
                    else
                        cb()
            , callback

    # Check version :
    #   * For npm repository 'cozy-dev'
    #   * For cozy stack
    # Log to user if a version isn't up-to-date.
    checkVersions: (appData, callback) =>
        # Check version for 'cozy-dev'
        log.info 'Check cozy-dev version :'

        child = exec 'npm show cozy-dev version', (err, stdout, stderr) =>
            version = stdout.replace /\n/g, ''

            if semver.gt(version, appData.version)
                log.warn 'A new version is available for cozy-dev, ' +
                    "you can enter 'npm -g update cozy-dev' to update it."
            else
                log.info "Cozy-dev is up to date.".green

            # Check version for cozy stack
            log.info 'Check cozy versions : '
            @stackVersions (need) ->
                if need
                    log.warn "A new version is available for cozy stack, " +
                        "you can enter cozy-dev vm:update to update it."
                else if need?
                    log.info "Cozy-dev is up to date.".green
                callback()
