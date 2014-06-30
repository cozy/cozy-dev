require 'colors'
path = require 'path'
fs = require 'fs'
Client = require('request-json').JsonClient
helpers = require './helpers'

class exports.RepoManager

    createLocalRepo: (appname, isCoffee, callback) ->

        cmds = []
        unless isCoffee
            repo = "https://github.com/cozy/cozy-template.git"
        else
            repo = "https://github.com/cozy/cozy-template-coffee.git"

        appPath = "#{process.cwd()}/#{appname}"

        cmds.push
            name: "git"
            args: ['clone', repo,  appname]
            opts:
                cwd: process.cwd()
        cmds.push
            name: "git"
            args: ['submodule', 'update', '--init', '--recursive']
            opts:
                cwd: appPath

        if helpers.isRunningOnWindows()
            removeGitFolderCommand =
                name: "rmdir"
                args: ['/S', '/Q', '.git']
                opts:
                    cwd: appPath
        else
            removeGitFolderCommand =
                name: "rm"
                args: ['-rf', '.git']
                opts:
                    cwd: appPath
        cmds.push removeGitFolderCommand

        cmds.push
            name: "npm"
            args: ['install']
            opts:
                cwd: appPath
        cmds.push
            name: "npm"
            args: ['install']
            opts:
                cwd: "#{appPath}/client"

        console.log "Creating the project structure..."

        helpers.spawnUntilEmpty cmds, (code) ->
            if code is 0
                console.log "Project structure created.".green
            else
                msg = "An error occurrend during project structure creation"
                console.log msg.red
            callback()

    connectRepos: (user, appname, callback) ->
        cmds = []
        appPath = "#{process.cwd()}/#{appname}"
        cmds.push
            name: "git"
            args: ['init']
            opts:
                cwd: appPath
        remoteRepository = "git@github.com:#{user}/#{appname}.git"
        cmds.push
            name: "git"
            args: ['remote', 'add', 'origin', remoteRepository]
            opts:
                cwd: appPath
        cmds.push
            name: "git"
            args: ['add', '.']
            opts:
                cwd: appPath
        cmds.push
            name: "git"
            args: ['commit', '-a', '-m', '"First commit."']
            opts:
                cwd: appPath
        cmds.push
            name: "git"
            args: ['push', 'origin', '-u', 'master']
            opts:
                cwd: appPath

        helpers.spawnUntilEmpty cmds, ->
            msg = "The project has been successfully linked to a Github " + \
                  "repository."
            console.log msg.green
            callback()

    createGithubRepo: (credentials, repo, callback) ->
        client = new Client 'https://api.github.com/'
        client.setBasicAuth credentials.username, credentials.password
        client.post 'user/repos', name: repo, (err, res, body) ->
            if err
                console.log "An error occured while creating repository.".red
                console.log err
            else if res.statusCode isnt 201
                console.log "Cannot create repository on Github.".red
                console.log body
            else
                callback()

    saveConfig: (githubUser, app, url, callback) ->
        data =
        """
            {
                "cozy": {
                    "appName": "#{app}",
                    "url": "#{url}"
                },
                "github": {
                    "user": "#{githubUser}",
                    "repoName": "#{app}"
                }
            }
        """
        fs.writeFile path.join(app, '.cozy_conf.json'), data, (err) ->
            if err
                console.log err.red
            else
                console.log "Config file successfully saved.".green
                callback()
