exec = require('child_process').exec
spawn = require('child_process').spawn

# Execute sequentially given shell commands until there is no more command left.
exports.executeUntilEmpty = (commands, callback) ->
    command = commands.shift()

    exec command, (err, stdout, stderr) ->

        if err isnt null
            console.log stderr
        else if commands.length > 0
            exports.executeUntilEmpty commands, callback
        else
            callback()

exports.executeSynchronously = (commands, callback) ->

    commandDescriptor = commands.shift()

    command = spawn(commandDescriptor.name, commandDescriptor.args)

    command.stdout.on 'data',  (data) ->
        console.log '' + data
    command.stderr.on 'data', (data) ->
        console.log '' + data

    command.on 'exit', (code) ->
        if commands.length > 0
            exports.executeSynchronously(commands, callback)
        else
            callback()

