require 'colors'
program = require 'commander'
path = require 'path'

Client = require("request-json").JsonClient
Client::configure = (url, password, callback) ->
    @host = url
    @post "login", password: password, (err, res) ->
        if err or res.statusCode != 200
            console.log "Cannot get authenticated"
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

### Tasks ###

program
    .version('0.2.0')
    .option('-u, --url <url>',
            'set url where lives your Cozy Cloud, default to localhost')
    .option('-g, --github <github>',
            'Link new project to github account')


program
    .command("install <app> <repo>")
    .description("Install given application from its repository")
    .action (app, repo) ->
        program.password "Cozy password:", (password) ->
            appManager.installApp app, program.url, repo, password, ->
                console.log "#{app} sucessfully installed.".green

program
    .command("uninstall <app>")
    .description("Uninstall given application")
    .action (app) ->
        program.password "Cozy password:", (password) ->
            appManager.uninstallApp app, program.url, password, ->
                console.log "#{app} sucessfully uninstalled.".green

program
    .command("update <app>")
    .description(
        "Update application (git + npm install) and restart it through haibu")
    .action (app) ->
        program.password "Cozy password:", (password) ->
            appManager.updateApp app, program.url, password, ->
                console.log "#{app} sucessfully updated.".green

program
    .command("status")
    .description("Give current state of cozy platform applications")
    .action ->
        program.password "Cozy password:", (password) ->
            appManager.checkStatus program.url, password, ->
                console.log "All apps have been checked.".green

program
    .command("new <appname>")
    .description("Create a new app suited to be deployed on a Cozy Cloud.")
    .action (appname) ->
        user = program.github

        if user?
            console.log "Create repo #{appname} for user #{user}..."
            program.password "Github password:", (password) =>
                program.prompt "Cozy Url:", (url) ->
                    projectManager.newProject appname, url, user, password, ->
                        console.log "Project creation finished.".green
                        process.exit 0
        else
            console.log "Create project folder: #{appname}"
            repoManager.createLocalRepo appname, ->
                console.log "Project creation finished.".green

program
    .command("deploy")
    .description("Push code and deploy app located in current directory " + \
                 "to Cozy Cloud url configured in configuration file.")
    .action ->
        config = require(path.join(process.cwd(), "deploy_config")).config
        program.password "Cozy password:", (password) ->
            projectManager.deploy config, password, ->
                console.log "#{config.cozy.appName} sucessfully deployed.".green

program
    .command("dev:init")
    .description("Initialize the current folder to host a virtual machine " + \
                 "with Vagrant. This will download the base box file.")
    .action ->
        console.log "Initializing the vritual machine in the folder..." + \
                    "this may take a while."
        vagrantManager.checkIfVagrantIsInstalled ->
            vagrantManager.vagrantBoxAdd ->
                vagrantManager.vagrantInit ->
                    msg = "The virtual machine has been successfully " + \
                          "initialized."
                    console.log msg.green

program
    .command("dev:start")
    .description("Starts the virtual machine with Vagrant.")
    .action ->
        vagrantManager.checkIfVagrantIsInstalled ->
            console.log "Starting the virtual machine...this may take a while."
            vagrantManager.vagrantUp ->
                msg = "The virtual machine has been successfully started. " + \
                      "You can check everything is working by running " + \
                      "cozy dev:vm-status"
                console.log msg.green

program
    .command("dev:stop")
    .description("Stops the Virtual machine with Vagrant.")
    .action ->
        vagrantManager.checkIfVagrantIsInstalled ->
            console.log "Stopping the virtual machine...this may take a while."
            vagrantManager.vagrantHalt ->
                msg = "The virtual machine has been successfully stopped."
                console.log msg.green

program
    .command("dev:vm-status")
    .description("Tells which services of the VM are running and accessible.")
    .action ->
        vagrantManager.checkIfVagrantIsInstalled ->
            vagrantManager.virtualMachineStatus ->
                console.log "All the tests have been done."

program
    .command("*")
    .description("Display error message for an unknown command.")
    .action ->
        console.log 'Unknown command, run "cozy --help"' + \
                    ' to know the list of available commands.'

program.parse process.argv
