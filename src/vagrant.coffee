require 'colors'
path = require 'path'
fs = require 'fs'
log = require('printit')
    prefix: 'vagrant    '
Client = require('request-json').JsonClient
exec = require('child_process').exec
spawn = require('child_process').spawn
compareVersions = require "mozilla-version-comparator"

helpers = require './helpers'

class exports.VagrantManager

    constructor: ->
        @baseBoxName = 'cozycloud/cozy-dev'

        @docURL = "http://cozy.io/hack/getting-started/setup-environment.html"

        # Minimum required version to make Vagrant work with cozy-dev
        @minimumVagrant = "1.5.0"

    checkIfVagrantIsInstalled: (callback) ->
        exec "vagrant -v", (err, stdout, stderr) =>
            if err
                msg =  "Vagrant is required to use a virtual machine. " + \
                        "Please, refer to our documentation on #{@docURL}"
                log.error msg.red
            else
                versionMatch = stdout.match /Vagrant ([\d\.]+)/
                if not versionMatch? or versionMatch.length isnt 2
                    msg = "Cannot correctly check the version using the " + \
                            "\"vagrant -v\" command. Please report an issue."
                    log.error msg.red
                    log.error "Output of \"vagrant -v\":\n#{stdout}.".red

                # If the installed version of Vagrant is older than the
                # required one, raise an error (see issue #31)
                else if compareVersions(@minimumVagrant, versionMatch[1]) > 0
                    msg = "cozy-dev requires Vagrant " + \
                            "#{@minimumVagrant} or later."
                    log.error msg.red
                else
                    callback() if callback?

    vagrantBoxAdd: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['box', 'add', @baseBoxName]
        helpers.spawnUntilEmpty cmds, ->
            msg = "The base box has been added to your environment or is " + \
                  "already installed."
            log.info msg.green
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
            args: ['destroy', '--force']
        cmds.push
            name: 'vagrant'
            args: ['box', 'remove', 'cozycloud/cozy-dev']
        cmds.push
            name: 'rm'
            args: ['-rf', 'Vagrantfile']
        helpers.spawnUntilEmpty cmds, callback

    vagrantBoxUpdate: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['box', 'update']
        helpers.spawnUntilEmpty cmds, callback

    # perform "up" if the vm has been "halt"
    # perform "resume" if the VM has been "suspend"
    vagrantUp: (callback) ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['up']
        helpers.spawnUntilEmpty cmds, (code) ->
            if code is 0
                log.info "Checking status ..."
                helpers.isStarted 0, ()->
                    callback()
            else
                callback code

    vagrantHalt: (callback)  ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['--force', 'halt']
        helpers.spawnUntilEmpty cmds, callback

    vagrantSuspend: (callback)  ->
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['suspend']
        helpers.spawnUntilEmpty cmds, callback

    update: (callback) ->
        log.info "Patching the updater and updating the VM..." + \
                 "This may take a while..."
        cmds = []
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', 'rm -rf ~/update-devenv.sh']

        scriptUrl = "https://raw.githubusercontent.com/cozy/" + \
                    "cozy-setup/master/dev/update-devenv.sh"
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', "curl -Of #{scriptUrl}"]
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', 'chmod u+x ~/update-devenv.sh']
        cmds.push
            name: 'vagrant'
            args: ['ssh', '-c', '~/update-devenv.sh']

        @importVagrantFile ->
            helpers.spawnUntilEmpty cmds, callback

    importVagrantFile: (callback) ->
        log.info "Importing latest Vagrantfile version..."
        url = "cozy/cozy-setup/master/dev/Vagrantfile"
        client = new Client "https://raw.githubusercontent.com/"
        client.saveFile url, './Vagrantfile', (err, res, body) ->
            if err
                msg = "An error occurrend while retrieving the Vagrantfile."
                log.error msg.red
            else
                log.info "Vagrantfile successfully upgraded.".green

            callback() if callback?

    virtualMachineStatus: (callback) ->
        url = "http://localhost:9104"
        log.info "Checking status on #{url}..."
        client = new Client url
        portInfo =
            couchdb: 5984
            datasystem: 9101
            controller: 9002
            indexer: 9102
            proxy: 9104
        client.get '/status', (err, res, body) ->
            if err
                callback 1
            else
                isOkay = 0
                for app, status of body when app not in ['registered']
                    if status is true
                        formattedStatus = "ok".green
                    else
                        formattedStatus = "ko".red
                        isOkay = 1

                    info = portInfo[app]
                    info = if info? then " (port: #{info})" else ""

                    log.info "\t* #{app}#{info}: #{formattedStatus}"
                callback isOkay

    getSshConfig: (callback) ->
        config = ''
        sshConf = {}
        cmd =
            name: 'vagrant'
            args: ['ssh-config']
        sshConfig = spawn cmd.name, cmd.args, cwd: process.cwd()
        sshConfig.stdout.on 'data', (data) ->
            config += data.toString()

        maybeErr = ''
        sshConfig.stderr.on 'data', (data) ->
            maybeErr += data

        sshConfig.on 'close', (err) ->
            if maybeErr isnt ''
                callback maybeErr
            else if config is ''
                callback 'No config'
            else
                configs = config.split('\n')
                for conf in configs
                    conf = conf.replace('  ', '')
                    params = conf.split(' ')
                    if params[0]? and params[1]?
                        sshConf[params[0]] = params[1]
                callback null, sshConf
