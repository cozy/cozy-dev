require 'colors'
log = require('printit')
    prefix: 'project   '
async = require 'async'
fs = require 'fs'
path = require 'path'

helpers = require './helpers'
{RepoManager} = require './repository'
{ApplicationManager} = require './application'

class exports.ProjectManager

    repoManager: new RepoManager()
    appManager: new ApplicationManager()

    newProject: (name, isCoffee, url, user, password, callback) ->
        credentials =
            password: password
            username: user

        async.series [
            (cb) => @repoManager.createGithubRepo credentials, name, cb
            (cb) => @repoManager.createLocalRepo name, isCoffee, cb
            (cb) => @repoManager.connectRepos user, name, cb
            (cb) => @repoManager.saveConfig user, name, url, cb
        ], callback


    deploy: (config, password, callback) ->
        name = config.cozy.appName
        url = config.cozy.url
        user = config.github.user
        repoName = config.github.repoName

        install = =>
            repoUrl = "https://github.com/#{user}/#{repoName}.git"
            @appManager.installApp name, url, repoUrl, password, callback

        update = =>
            @appManager.updateApp name, url, password, callback

        @appManager.isInstalled name, url, password, (err, isInstalled) ->
            if err?
                msg = "Error occured while connecting to your Cozy Cloud."
                log.error msg.red
            else if isInstalled
                update()
            else
                install()

    recoverManifest: (port, cb) ->
        unless fs.existsSync 'package.json'
            log.error "Cannot read package.json. " +
                "This function should be called in root application folder."
        else
            try
                packagePath = path.relative __dirname, 'package.json'
                manifest = require packagePath
            catch err
                log.raw err
                log.error "Package.json isn't correctly formatted."
                callback err
                return

            # Retrieve manifest from package.json
            manifest.permissions = manifest['cozy-permissions']
            manifest.name = manifest.name.replace 'cozy-', ''
            manifest.slug = manifest.name
            manifest.displayName =
                manifest['cozy-displayName'] or manifest.slug
            manifest.state = "installed"
            manifest.autostop = false
            manifest.password = 'test'
            manifest.docType = "Application"
            manifest.port = port
            cb null, manifest