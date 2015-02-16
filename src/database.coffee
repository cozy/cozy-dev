require 'colors'
fs = require 'fs'
{exec} = require 'child_process'
async = require 'async'
log = require('printit')
    prefix: 'database-manager'

Client = require('request-json').JsonClient

module.exports = class DatabaseManager


    switch: (newName, callback) ->

        fileName = 'controller.json'
        filePath = "/etc/cozy/#{fileName}"

        async.series

            getConfig: (next) ->
                command = """
                vagrant ssh -c "sudo cp #{filePath} /vagrant/"
                """
                log.info 'Getting current configuration...'
                exec command, (err, stderr, stdout) ->
                    if err? or stderr
                        err = err or stderr
                        next err
                    else
                        next()

            updateConfig: (next) ->
                try
                    options = encoding: 'utf-8'
                    rawConfig = fs.readFileSync './controller.json', options
                    config = JSON.parse rawConfig
                    config.env ?= {}

                    unless config.env['data-system']
                        config.env['data-system'] = {}

                    config.env['data-system']['DB_NAME'] = newName
                    newRawConfig = JSON.stringify config
                    fs.writeFileSync './controller.json', newRawConfig
                    next()
                catch err
                    next err

            writeConfig: (next) ->
                command = """
                vagrant ssh -c "sudo mv /vagrant/#{fileName} #{filePath}"
                """
                log.info 'Updating new configuration...'
                exec command, (err, stderr, stdout) ->
                    if err? or stderr
                        err = err or stderr
                        next err
                    else
                        next()

            restartController: (next) ->
                command = """
                vagrant ssh -c "sudo supervisorctl restart cozy-controller"
                """
                log.info 'Restarting controller...'
                exec command, (err, stderr, stdout) ->
                    # supervisor outputs its logs to stderr...
                    next err

        , (err) ->
            if err?
                msg = "An error occured while changing Cozy's configuration"
                log.error "#{msg} -- #{err}".red
            else
                log.info "Database successfully switched to #{newName}".green
            callback()


    reset: (dbName, callback) ->

        async.series

            removeDatabase: (next) ->
                log.info 'Resetting database...'
                couch = new Client 'http://localhost:5984'
                couch.del "#{dbName}", (err, res, body) ->
                    err = err or body.error
                    next err

            restartController: (next) ->
                command = """
                vagrant ssh -c "sudo supervisorctl restart cozy-controller"
                """
                log.info 'Restarting controller...'
                exec command, (err, stderr, stdout) ->
                    # supervisor outputs its logs to stderr...
                    next err

        , (err) ->
            if err?
                msg = "An error occured while reseting database"
                log.error "#{msg} -- #{err}".red
            else
                log.info "Database #{dbName} successfully reset.".green
            callback()
