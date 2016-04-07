require 'colors'
program = require 'commander'
path = require 'path'
log = require('printit')
    prefix: 'cozy-dev   '
inquirer = require 'inquirer'
async = require 'async'

Client = require("request-json").JsonClient
Client::configure = (url, password, callback) ->
    @host = url
    @post "login", password: password, (err, res) ->
        if err? or res?.statusCode isnt 200
            log.error "Cannot get authenticated"
        else
            callback()

client = new Client ""

RepoManager = require('./repository').RepoManager
repoManager = new RepoManager()
ApplicationManager = require('./application').ApplicationManager
appManager = new ApplicationManager()
ProjectManager = require('./project').ProjectManager
projectManager = new ProjectManager()
VagrantManager = require('./vagrant').VagrantManager
vagrantManager = new VagrantManager()
DatabaseManager = require('./database')
databaseManager = new DatabaseManager()

helpers = require './helpers'

appData = require '../package.json'

### Tasks ###
program
.version appData.version
.option '-u, --url <url>', 'Set url where lives your Cozy Cloud, default ' + \
        'to localhost'
.option '-g, --github <github>', 'Link new project to github account'
.option '-c, --coffee', 'Create app template with coffee script files ' + \
        'instead of JS files'


program
.command "uninstall <app>"
.description "Uninstall given application"
.action (app) ->
    async.waterfall [
        helpers.promptPassword 'Cozy password'
        (password, cb) -> appManager.uninstallApp app, program.url, password, cb
    ], ->
        log.info "#{app} successfully uninstalled.".green


program
.command "update <app>"
.description "Update application (git + npm install) and restart it " + \
             "through haibu"
.action (app) ->
    async.waterfall [
        helpers.promptPassword 'Cozy password'
        (password, cb) ->
            appManager.updateApp app, program.url, password, cb
    ], ->
        log.info "#{app} successfully updated.".green


program
.command "new <appname>"
.description "Create a new app suited to be deployed on a Cozy Cloud."
.action (appname) ->
    user = program.github
    isCoffee = program.coffee

    if user?
        log.info "Create repo #{appname} for user #{user}..."
        async.waterfall [
            helpers.promptPassword 'Github password'

            (password, cb) ->
                options =
                    type: 'input'
                    name: 'url'
                    message: 'Cozy URL'
                inquirer.prompt options, (answers) ->
                    cb null, password, answers.url

            (password, url, cb) ->
                projectManager.newProject(appname, isCoffee, url, user, \
                                         password, cb)

        ], ->
            log.info "Project creation finished.".green
            process.exit 0
    else
        log.info "Create project folder: #{appname}"
        repoManager.createLocalRepo appname, isCoffee, ->
            log.info "Project creation finished.".green

# Install application for cozy stack
program
.command "deploy <port> [slug]"
.description """Push code and deploy app located in current directory to your \
             virtualbox. Argument port correspond to port used by your \
             application, or to the path containing your built static assets \
             for a server-less app."""
.action (port, slug) ->
    port = 9250 unless port?
    # Recover manifest
    options = {slug, port}
    projectManager.recoverManifest options, (err, app) ->
        return log.error err if err?

        if app.name in ['home', 'data-system', 'proxy']
            # Stack application
            steps = [
                (cb) -> appManager.stopApp app.name, cb
                (cb) -> appManager.addPortForwarding app.name, app.port, cb
            ]
        else
            # User application
            steps = [
                (cb) -> appManager.addInDatabase app, cb
                (cb) -> appManager.resetProxy cb
                (cb) -> appManager.configLocalApp 'add', app, cb
            ]

        async.series steps, (err) ->
            return log.error err if err?
            msg = "Application deployed in virtual machine."
            log.info msg.green

            unless app.name in ['home', 'data-system', 'proxy']
                appUrl = "http://localhost:9104/#apps/#{app.slug}"
                log.info "You can see your app on #{appUrl}"

# Uninstall application for cozy stack
program
.command "undeploy [slug]"
.description "Undeploy application"
.action (slug) ->
    # Recover manifest
    options =
        slug: slug
        port: 9250
    projectManager.recoverManifest options, (err, app) ->
        return log.error err if err?

        if app.name in ['home', 'data-system', 'proxy']
            # Stack application
            steps = [
                (cb) -> appManager.removePortForwarding app.name, app.port, cb
                (cb) -> appManager.startApp app.name, cb
            ]
        else
            # User application
            steps = [
                (cb) -> appManager.removeFromDatabase app, cb
                (cb) -> appManager.resetProxy cb
                (cb) -> appManager.configLocalApp 'remove', app, cb
            ]

        async.series steps, (err) ->
            return log.error err if err?
            msg = "Application undeployed in virtual machine."
            log.info msg.green

program
.command "vm:init"
.description "Initialize the current folder to host a virtual machine " + \
             "with Vagrant. This will download the base box file."
.action ->
    log.info "Initializing the virtual machine in the folder..." + \
             "this may take a while."

    async.series [
        (cb) -> vagrantManager.checkIfVagrantIsInstalled cb
        (cb) -> vagrantManager.vagrantBoxAdd cb
        (cb) -> vagrantManager.vagrantInit cb
    ], ->
        msg = "The virtual machine has been successfully initialized."
        log.info msg.green

program
.command "vm:start"
.description "Starts the virtual machine with Vagrant."
.action ->
    async.series [
        (cb) -> vagrantManager.checkIfVagrantIsInstalled cb
        (cb) ->
            log.info "Starting the virtual machine...this may take a while."
            vagrantManager.vagrantUp cb
        (cb) -> vagrantManager.virtualMachineStatus (status) -> cb()
        (cb) -> appManager.checkVersions appData, cb
    ], (err, results) ->

        if not err?
            msg = "The virtual machine has been successfully started."
            log.info msg.green
        else
            msg = "An error occurred while your VMs was starting."
            log.error msg.red

haltOption = "Properly stop the virtual machine instead of simply " + \
             "suspending its execution"
program
.command "vm:stop"
.description "Stops the Virtual machine with Vagrant."
.action () ->
    async.series [
        (cb) -> vagrantManager.checkIfVagrantIsInstalled cb
        (cb) ->
            log.info "Stopping the virtual machine...this may take a while."
            vagrantManager.vagrantHalt (code) -> cb null, code
    ], (err, results) ->
        [_, code] = results

        if code is 0
            msg = "The virtual machine has been successfully stopped."
            log.info msg.green
        else
            msg = "An error occurred while your VMs was shutting down."
            log.error msg.red
program
.command "vm:status"
.description "Tells which services of the VM are running and accessible."
.action ->
    async.series [
        (cb) -> vagrantManager.checkIfVagrantIsInstalled cb
        (cb) -> vagrantManager.virtualMachineStatus (code) -> cb null, code
    ], (err, results) ->
        [_, code] = results

        if code is 0
            log.info "All the core services are up and running.".green
        else
            log.error "One or more services are not running.".red

program
.command "vm:update"
.description "Updates the virtual machine with the latest version of " + \
             "the cozy PaaS and core applications"
.action ->
    async.series [
        (cb) -> vagrantManager.checkIfVagrantIsInstalled cb
        (cb) -> vagrantManager.update (code) -> cb null, code
    ], (err, results) ->
        [_, code] = results

        if code is 0
            log.info "VM updated.".green
        else
            log.error "An error occurred while updating the VM".red

program
.command "vm:update-image"
.description "Updates the virtual machine image. " +
            "Warning: this action deletes all your data in your virtualbox"
.action ->
    confirmMessage = "You are about to update image of the virtual machine." + \
                     " All your data will be lost. Are you sure ?"
    options =
        type: 'confirm'
        name: 'hasConfirm'
        message: confirmMessage
        default: true
    inquirer.prompt options, (answers) ->
        if answers.hasConfirm
            async.series [
                (cb) -> vagrantManager.checkIfVagrantIsInstalled cb
                (cb) ->
                    log.info "Update the old virtual machine..."
                    vagrantManager.vagrantBoxUpdate cb
                (cb) -> databaseManager.getCurrentDatabase cb
            ], (err, results) ->
                if err
                    log.info err
                    log.error "An error occurred while updating the VM".red
                else
                    log.info "VM updated.".green


program
.command "vm:destroy"
.description "Destroy the virtual machine. Data will be lost."
.action ->
    confirmMessage = "You are about to remove the virtual machine from " + \
                     "your computer. All data will be lost and a new " + \
                     "import will be required if you want to use the " + \
                     "VM again"

    async.waterfall [
        (cb) ->
            options =
                type: 'confirm'
                name: 'hasConfirm'
                message: confirmMessage
                default: true
            inquirer.prompt options, (answers) -> cb null, answers.hasConfirm

        (hasConfirm, cb) ->
            if hasConfirm
                vagrantManager.vagrantBoxDestroy cb
            else cb()
    ], ->
        msg = "The box has been successfully destroyed. Use " + \
                "cozy vm:init to be able to use the VM again."
        log.info msg.green
        process.exit()


program
.command "db:switch [dbname]"
.description "Change the database used by Cozy's data system (default: cozy)."
.action (dbname) ->
    dbname = dbname or 'cozy'
    databaseManager.switch dbname, (err) ->
        returnCode = if err? then 1 else 0
        process.exit returnCode


program
.command "db:reset <dbname>"
.description "Reset the given database (will destroy all data)."
.option "-f, --force", "Bypass the confirmation message. USE AT YOUR OWN RISK."
.action (dbname, args) ->

    processReset = ->
        databaseManager.reset dbname, (err) ->
            returnCode = if err? then 1 else 0
            process.exit returnCode

    if args.force?
        processReset()
    else
        confirmMessage = "You are about to reset the database #{dbname}. " + \
                         "All data will be lost. Are you sure?"
        options =
            type: 'confirm'
            name: 'hasConfirmed'
            message: confirmMessage
            default: true
        inquirer.prompt options, (answers) ->
            if answers.hasConfirmed
                processReset()
            else
                process.exit 0

program
.command "db:name"
.description "Returns the current used database"
.action ->
    databaseManager.getCurrentDatabase (err) ->
        returnCode = if err? then 1 else 0
        process.exit returnCode


program
.command "*"
.description "Display help message for an unknown command."
.action ->
    log.error 'Unknown command, showing help instead.'
    program.help()

program.parse process.argv

unless process.argv.length > 2
    program.help()
