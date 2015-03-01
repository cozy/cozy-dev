{spawn} = require 'child_process'
os = require 'os'
path = require 'path'
inquirer = require 'inquirer'
Client = require('request-json').JsonClient

# Execute sequentially given shell commands with "spawn"
# until there is no more command left. Spawn displays the output as it comes.
module.exports.spawnUntilEmpty = (commands, callback) ->
    commandDescriptor = commands.shift()
    if module.exports.isRunningOnWindows()
        name = commandDescriptor.name
        commandDescriptor.name = "cmd"
        commandDescriptor.args.unshift name
        commandDescriptor.args.unshift '/C'

    command = spawn(commandDescriptor.name, commandDescriptor.args,
                    commandDescriptor.opts)

    if os.platform().match /^win/
        name = commandDescriptor.name
        commandDescriptor.name = "cmd"
        commandDescriptor.args.unshift name
        commandDescriptor.args.unshift '/C'

    command.stdout.pipe process.stdout
    command.stderr.pipe process.stderr

    command.on 'close', (code, signal) ->
        if commands.length > 0 and code is 0
            module.exports.spawnUntilEmpty commands, callback
        else
            callback code

isStarted = module.exports.isStarted = (count, callback) ->
    if count > 10
        callback()
    else
        client = new Client "http://localhost:9104"
        client.get '/status', (err, res, body) ->
            if err
                setTimeout ->
                    isStarted count + 1, callback
                , 1 * 1000
            else
                for app, status of body when app is 'controller'
                    if status is true
                        callback()
                    else
                        setTimeout ->
                            isStarted count + 1, callback
                        , 1 * 1000

module.exports.isRunningOnWindows = -> return os.platform().match /^win/

module.exports.promptPassword = (name) -> (cb) ->
    options =
        type: 'password'
        name: 'password'
        message: name
    inquirer.prompt options, (answers) ->
        cb null, answers.password

module.exports.getPidFile = (name) ->
    if module.exports.isRunningOnWindows()
        home =
            process.env.HOME or
            process.env.HOMEPATH or
            process.env.USERPROFILE
        return path.join home, "#{name}.pid"
    else
        return path.join '/tmp', "#{name}.pid"
