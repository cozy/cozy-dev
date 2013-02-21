require 'colors'
path = require 'path'
fs = require 'fs'

Client = require('request-json').JsonClient
helpers = require './helpers'


class exports.RepoManager

    createLocalRepo: (appname, callback) ->
        console.log "Github repo created succesfully."
        cmds = []
        cmds.push "git clone https://github.com/mycozycloud/cozy-template.git #{appname}"
        cmds.push "cd #{appname} && git submodule update --init --recursive"
        cmds.push "cd #{appname} && rm -rf .git"
        cmds.push "cd #{appname} && npm install"
        cmds.push "cd #{appname}/client && npm install"

        console.log "Create new directory for your app"
        helpers.executeUntilEmpty cmds, ->
            console.log "Project directory created.".green
            callback()

    connectRepos: (user, appname, callback) ->
        cmds = []
        cmds.push "cd #{appname} && git init"
        cmds.push "cd #{appname} && git remote add " + \
            "origin git@github.com:#{user}/#{appname}.git"
        cmds.push "cd #{appname} && git add ."
        cmds.push "cd #{appname} && git commit -a -m \"first commit\""
        cmds.push "cd #{appname} && git push origin -u master"
        helpers.executeUntilEmpty cmds, ->
            console.log "Project linked to github repo.".green
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
            exports.config =
                cozy:
                    appName: "#{app}"
                    url: "#{url}"
                github:
                    user: "#{githubUser}"
                    repoName: "#{app}"

        """
        fs.writeFile path.join(app, 'deploy_config.coffee'), data, (err) ->
            if err
                console.log err.red
            else
                console.log "Config file successfully saved.".green
                callback()
