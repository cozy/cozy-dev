require 'colors'
path = require 'path'
fs = require 'fs'
Client = require('request-json').JsonClient
exec = require('child_process').exec

helpers = require './helpers'

class exports.VagrantManager

    constructor: ->
        @baseBoxURL = 'http://files.cozycloud.cc/cozycloud-dev-latest.box'

        page = 'Setup-cozy-cloud-development-environment-via-a-virtual-machine'
        @docURL = "https://github.com/mycozycloud/cozy-setup/wiki/#{page}"

    checkIfVagrantIsInstalled: (callback) ->
        exec "vagrant -v", (err, stdout, stderr) =>
            if err
                msg =  "Vagrant is required to use a virtual machine. " + \
                        "Please, refer to our documentation on #{@docURL}"
                console.log msg.red
            else
                callback() if callback?

    vagrantBoxAdd: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['box', 'add', 'cozycloud-dev-latest', @baseBoxURL]
        helpers.spawnUntilEmpty cmds, ->
            msg = "The base box has been added to your environment or is " + \
                  "already installed."
            console.log msg.green
            callback() if callback?

    vagrantInit: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['init', "cozy-dev-latest"]
        helpers.spawnUntilEmpty cmds, =>
            @importVagrantFile callback

    vagrantBoxDestroy: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['--force', 'destroy']
        cmds.push
            name: 'vagrant'
            args: ['box', 'remove', 'cozycloud-dev-latest']
        cmds.push
            name: 'rm'
            args: ['-rf', 'Vagrantfile']
        helpers.spawnUntilEmpty cmds, callback

    # perform "up" if the vm has been "halt"
    # perform "resume" if the VM has been "suspend"
    vagrantUp: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['up']
        helpers.spawnUntilEmpty cmds, callback

    vagrantHalt: (callback)  ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['halt']
        helpers.spawnUntilEmpty cmds, callback

    vagrantSuspend: (callback)  ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['suspend']
        helpers.spawnUntilEmpty cmds, callback

    lightUpdate: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', '"rm -rf ~/update-devenv.sh"']
        scriptUrl = "https://raw.github.com/mycozycloud/cozy-setup/master/" + \
                                                       "dev/update-devenv.sh"
        cmds.push
            name: 'vagrant ssh'
            args: ['-c', '"curl -Of ' + scriptUrl + '"']
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', '"~/update-devenv.sh"']

        @importVagrantFile () ->
            helpers.spawnUntilEmpty cmds, callback

    importVagrantFile: (callback) ->
        console.log "Importing latest Vagrantfile version..."
        url = "mycozycloud/cozy-setup/master/dev/Vagrantfile"
        client = new Client "https://raw.github.com/"
        client.saveFile url, './Vagrantfile', (err, res, body) ->
            if err
                msg = "An error occurrend while retrieving the Vagrantfile."
                console.log msg.red
            else
                console.log "Vagrantfile successfully upgraded.".green

            callback() if callback?

    virtualMachineStatus: (callback) ->
        url = "http://localhost:9104"
        console.log "Checking status on #{url}..."
        client = new Client url
        client.get '/status', (err, res, body) ->
            if err
                callback(1)
            else
                isOkay = 0
                for app, status of body
                    if status is true
                        formattedStatus = "running".green
                    else
                        formattedStatus = "stopped".red
                        isOkay = 1
                    console.log "\t* #{app}: #{formattedStatus}"
                callback(isOkay)
