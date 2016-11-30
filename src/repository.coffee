require 'colors'
path = require 'path'
fs = require 'fs'
Client = require('request-json').JsonClient
log = require('printit')
    prefix: 'repository '

helpers = require './helpers'

class exports.RepoManager

    createLocalRepo: (appname, callback) ->

        cmds = []
        repo = "https://github.com/cozy/cozy-template.git"

        appPath = "#{process.cwd()}/#{appname}"

        cmds.push
            name: "git"
            args: ['clone', repo,  appname]
            opts: cwd: process.cwd()
        cmds.push
            name: "git"
            args: ['submodule', 'update', '--init', '--recursive']
            opts: cwd: appPath

        if helpers.isRunningOnWindows()
            removeGitFolderCommand =
                name: "rmdir"
                args: ['/S', '/Q', '.git']
                opts: cwd: appPath
        else
            removeGitFolderCommand =
                name: "rm"
                args: ['-rf', '.git']
                opts: cwd: appPath
        cmds.push removeGitFolderCommand

        cmds.push
            name: "npm"
            args: ['install']
            opts: cwd: appPath
        cmds.push
            name: "npm"
            args: ['install']
            opts: cwd: "#{appPath}/client"

        log.info "Creating the project structure..."

        helpers.spawnUntilEmpty cmds, (code) ->
            if code is 0
                log.info "Project structure created.".green
            else
                msg = "An error occurred during project structure creation"
                log.error msg.red
            callback()

    connectRepos: (user, appname, callback) ->
        cmds = []
        appPath = "#{process.cwd()}/#{appname}"
        cmds.push
            name: "git"
            args: ['init']
            opts: cwd: appPath
        remoteRepository = "git@github.com:#{user}/#{appname}.git"
        cmds.push
            name: "git"
            args: ['remote', 'add', 'origin', remoteRepository]
            opts: cwd: appPath
        cmds.push
            name: "git"
            args: ['add', '.']
            opts: cwd: appPath
        cmds.push
            name: "git"
            args: ['commit', '-a', '-m', '"First commit."']
            opts: cwd: appPath
        cmds.push
            name: "git"
            args: ['push', 'origin', '-u', 'master']
            opts: cwd: appPath

        helpers.spawnUntilEmpty cmds, ->
            msg = "The project has been successfully linked to a Github " + \
                  "repository."
            log.info msg.green
            callback()

    createGithubRepo: (credentials, repo, callback) ->
        client = new Client 'https://api.github.com/'
        client.setBasicAuth credentials.username, credentials.password
        client.post 'user/repos', name: repo, (err, res, body) ->
            if err
                log.error "An error occured while creating repository.".red
                log.error err
            else if res.statusCode isnt 201
                log.error "Cannot create repository on Github.".red
                log.error body
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
            if err?
                log.error err.red
            else
                log.info "Config file successfully saved.".green
                callback()
