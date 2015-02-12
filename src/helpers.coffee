{spawn} = require 'child_process'
os = require 'os'
util = require 'util'
log = require('printit')
    prefix: 'helpers    '
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

    command.stdout.on 'data',  (data) ->
        util.print "#{data}"

    command.stderr.on 'data', (data) ->
        util.print "#{data}"

    command.on 'close', (code, signal) ->
        if commands.length > 0 and code is 0
            module.exports.spawnUntilEmpty commands, callback
        else
            callback code


isStarted = module.exports.isStarted = (callback) ->
    url = "http://localhost:9104"
    client = new Client url
    client.get '/status', (err, res, body) ->
        if err
            setTimeout () ->
                isStarted callback
            , 1 * 1000
        else
            callback()

module.exports.isRunningOnWindows = -> return os.platform().match /^win/

module.exports.promptPassword = (name) -> (cb) ->
    options =
        type: 'password'
        name: 'password'
        message: name
    inquirer.prompt options, (answers) ->
        cb null, answers.password
