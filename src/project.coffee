require 'colors'
log = require('printit')
    prefix: 'project   '
async = require 'async'

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
