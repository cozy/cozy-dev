require 'colors'
helpers = require './helpers'
RepoManager = require('./repository').RepoManager
ApplicationManager = require('./application').ApplicationManager

class exports.ProjectManager

    repoManager: new RepoManager()
    appManager: new ApplicationManager()

    newProject: (name, url, user, password, callback) ->
        credentials =
            password: password
            username: user

        @repoManager.createGithubRepo credentials, name, =>
            @repoManager.createLocalRepo name, =>
                @repoManager.connectRepos user, name, =>
                    @repoManager.saveConfig user, name, url, ->
                        callback()

    deploy: (config, password, callback) ->
        name = config.cozy.appName
        url = config.cozy.url
        user = config.github.user
        repoName = config.github.repoName

        install = =>
            repoUrl = "https://github.com/#{user}/#{repoName}.git"
            @appManager.installApp name, url, repoUrl, password, ->
                callback()

        update = =>
            @appManager.updateApp name, url, password, ->
                callback()

        @appManager.isInstalled name, url, password, (err, isInstalled) ->
            if err
                console.log "Error occured while connecting" + \
                            "to your Cozy Cloud.".red
            else if isInstalled
                update()
            else
                install()
