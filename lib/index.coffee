require "colors"

exec = require('child_process').exec
fs = require 'fs'
path = require 'path'
program = require 'commander'
async = require "async"
request = require 'request'

Client = require("request-json").JsonClient

### Helpers ###


executeUntilEmpty = (commands, callback) ->
    command = commands.shift()
  
    exec command, (err, stdout, stderr) ->
        if err isnt null
            console.log stderr
          
        else if commands.length > 0
            executeUntilEmpty commands, callback

        else
            callback()

createLocalRepo = (appname, callback) ->
    console.log "Github repo created succesfully."
    cmds = []
    cmds.push "git clone https://github.com/mycozycloud/cozy-template.git #{appname}"
    cmds.push "cd #{appname} && git submodule update --init --recursive"
    cmds.push "cd #{appname} && rm -rf .git"
    cmds.push "cd #{appname} && npm install"
    cmds.push "cd #{appname}/client && npm install"

    console.log "Create new directory for your app"
    executeUntilEmpty cmds, =>
        console.log "Project directory created."
        callback()

connectRepos = (user, appname, callback) ->
    cmds = []
    cmds.push "cd #{appname} && git init"
    cmds.push "cd #{appname} && git remote add " + \
        "origin git@github.com:#{user}/#{appname}.git"
    cmds.push "cd #{appname} && git add ."
    cmds.push "cd #{appname} && git commit -a -m \"first commit\""
    cmds.push "cd #{appname} && git push origin -u master"
    executeUntilEmpty cmds, ->
        console.log "Project linked to github repo."
        callback()
 

createGithubRepo = (credentials, repo, callback) ->
    auth = credentials.username + ':' + credentials.password
    auth = new Buffer(auth).toString('base64')
    requestData =
        method: "POST"
        uri: 'https://api.github.com/user/repos'
        json:
            name: repo
        headers:
            authorization: "Basic #{auth}"
    request requestData, (err, res, body) ->
        if err
            console.log "An error occured while creating repository."
            console.log err
        else if res.statusCode is not 201
            console.log "Cannot create repository on Github."
            console.log body
        else
            callback()

saveConfig = (githubUser, app, url, callback) ->
    data =
    """
        exports.config =
            cozy:
                appName: #{app}
                url: #{url}
            github:
                user: #{githubUser}
                repoName: #{app}

    """
    fs.writeFile path.join(repo, 'deploy_config.coffee'), data, (err) ->
        if err
            console.log err
        else
            console.log "Config file successfully saved."
            callback()


Client::configure = (url, password, callback) ->
    @host = url
    @post "login", password: password, (err, res) ->
        if err or res.statusCode != 200
            console.log "Cannot get authenticated"
        else
            callback()

client = new Client ""

updateApp = (app, url, password, callback) ->
    console.log "Update #{app}..."
    client.configure url, password, ->
        path = "api/applications/#{app}/update"
        client.put path, {}, (err, res, body) ->
            if err or res.statusCode isnt 200
                console.log err if err?
                console.log "Update failed"
                if body?
                    if body.msg?
                        console.log body.msg
                    else
                        console.log body
            else
                callback()


installApp = (app, url, repoUrl, password, callback) ->
    console.log "Install started for #{app}..."
    client.configure url, password, ->
        app_descriptor =
            name: app
            git: repoUrl

        path = "api/applications/install"
        client.post path, app_descriptor, (err, res, body) ->
            if err or res.statusCode isnt 201
                console.log err if err?
                console.log "Install failed"
                if body?
                    if body.msg?
                        console.log body.msg
                    else
                        console.log body
            else
                callback()


### Tasks ###

program
    .version('0.1.0')
    .option('-u, --url <url>',
            'set url where lives your Cozy Cloud, default to localhost')
    .option('-p, --password <password>',
            'Password required to connect on your Cozy Cloud')
    .option('-g, --github <github>',
            'Link new project to github account')


program
    .command("install <app> <repo>")
    .description("Install given application from its repository")
    .action (app, repo) ->
        installApp app, program.url, repo, program.password, ->
            console.log "#{app} sucessfully installed"
          
program
    .command("uninstall <app>")
    .description("Uninstall given application")
    .action (app) ->
        console.log "Uninstall started for #{app}..."
        client.configure ->
            path = "api/applications/#{app}/uninstall"
            client.del path, (err, res, body) ->
                if err or res.statusCode isnt 200
                    console.log err if err?
                    console.log "Uninstall failed"
                    if body?
                        if body.msg?
                            console.log body.msg
                        else
                            console.log body
                else
                    console.log "#{app} sucessfully uninstalled"

program
    .command("update <app>")
    .description(
        "Update application (git + npm install) and restart it through haibu")
    .action (app) ->
        updateApp app, program.url, program.password, ->
            console.log "#{app} sucessfully updated"

program
    .command("reset-proxy")
    .description("Reset proxy routes list of applications given by home.")
    .action ->
        console.log "Reset proxy routes"
        client.host = program.url if program.url?
        client.get "routes/reset", (err) ->
            if err
                console.log err
                console.log "Reset proxy failed."
            else
                console.log "Reset proxy succeeded."

program
    .command("routes")
    .description("Display routes currently configured inside proxy.")
    .action ->
        console.log "Display proxy routes..."
        client.host = program.url if program.url?
        
        client.get "routes", (err, res, routes) ->
            if not err and routes?
                console.log "#{route} => #{routes[route]}" for route of routes
                
program
    .command("status")
    .description("Give current state of cozy platform applications")
    .action ->
        checkApp = (app) ->
            (callback) ->
                if app isnt "home" and app isnt "proxy"
                    path = "apps/#{app}/"
                else path = ""

                client.get path, (err, res) ->
                    if err or res.statusCode != 200
                        console.log "#{app}: " + "down".red
                    else
                        console.log "#{app}: " + "up".green
                    callback()

        checkStatus = ->
            async.series [
                checkApp("home")
                checkApp("proxy", "routes")
            ], ->
                client.get "api/applications/", (err, res, apps) ->
                    if err
                        console.log err
                    else
                        funcs = []
                        if apps? and typeof apps == "object"
                            funcs.push checkApp(app.name) for app in apps.rows
                            async.series funcs, ->
     
        client = new Client ""
        client.configure checkStatus

program
    .command("new <appname>")
    .description("Create a new app suited to be deployed on a Cozy Cloud.")
    .action (appname) ->
        user = program.github

        if user?
            program.password "Github password:", (password) =>

                console.log "Create repo #{appname} for user #{user}..."
                credentials =
                    username: user
                    password: password

                createGithubRepo credentials, appname, =>
                    createLocalRepo appname, =>
                        connectRepos user, appname, =>
                           program.prompt "Cozy Url:", (url) ->
                                saveConfig user, appname, url, ->
                                    console.log "project creation finished."
                                    process.exit 0

        else
            createLocalRepo appname

program
    .command("deploy")
    .description("Push code and deploy app located in current directory to Cozy Cloud url configured in configuration file.")
    .action ->
        config = require path.join(__dirname, "config")
        program.password "Cozy password:", (password) ->
            if false
                updateApp config.github.repoName, config.cozy.url, password ->
                    console.log "#{app} sucessfully deployed."
            else
                repoUrl = "https://github.com/#{config.github.user}/#{config.github.repo}.git"
                installApp config.cozy.appName, config.cozy.url, repoUrl, password ->
                    console.log "#{app} sucessfully deployed."

program
    .command("*")
    .description("Display error message for an unknown command.")
    .action ->
        console.log 'Unknown command, run "coffee monitor --help"' + \
                    ' to know the list of available commands.'
                    
program.parse(process.argv)
