require 'colors'
fs = require 'fs'
{exec} = require 'child_process'
async = require 'async'
log = require('printit')
    prefix: 'database-manager'

Client = require('request-json').JsonClient

CONTROLLER_CONFIG = 'controller.json'
CONTROLLER_CONFIG_PATH = "/etc/cozy/#{CONTROLLER_CONFIG}"

module.exports = class DatabaseManager


    switch: (newName, callback) ->

        async.waterfall [
            # get config
            (next) ->
                command = """
                vagrant ssh -c "sudo cat #{CONTROLLER_CONFIG_PATH} 1>&2"
                """
                log.info 'Getting current configuration...'
                exec command, (err, stderr, stdout) ->
                    if err?
                        log.info 'No custom config found, creating one...'
                        config = '{}'
                        next null, config
                    else
                        next null, stdout

            # update config
            (rawConfig, next) ->
                try
                    # Extract JSON from controller configuration
                    config = JSON.parse rawConfig
                    config.env ?= {}

                    unless config.env['data-system']
                        config.env['data-system'] = {}

                    # Override DB_NAME configuration
                    config.env['data-system']['DB_NAME'] = newName
                    newRawConfig = JSON.stringify config, null, ' '
                    next null, newRawConfig
                catch err
                    next err

            # write config
            (rawConfig, next) ->
                # escape JSON for the bash command
                rawConfig = rawConfig.replace /"/g, "\\\\\\\""
                subCommand = """
                echo \\"#{rawConfig}\\" |
                sudo tee #{CONTROLLER_CONFIG_PATH} >> /dev/null
                """
                command = """
                vagrant ssh -c "#{subCommand}"
                """
                log.info 'Updating new configuration...'
                exec command, (err, stderr, stdout) ->
                    if err? or stderr
                        err = err or stderr
                        next err
                    else
                        next()

            # restart controller
            (next) ->
                command = """
                vagrant ssh -c "sudo supervisorctl restart cozy-controller"
                """
                log.info 'Restarting controller...'
                exec command, (err, stderr, stdout) ->
                    # supervisor outputs its logs to stderr...
                    next err

        ], (err) ->
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

    getCurrentDatabase: (callback) ->

        command = """
        vagrant ssh -c "sudo cat #{CONTROLLER_CONFIG_PATH}"
        """
        exec command, (err, stdout, stderr) ->
            try
                config = if err then {} else JSON.parse stdout
                databaseName = config?.env?['data-system']?['DB_NAME']

                # default is cozy
                databaseName ?= 'cozy'
                log.info "Current database is \"#{databaseName}\""
                callback()

            catch err
                msg = "An error occured while getting database name"
                log.error "#{msg} -- #{err}".red
                callback err
