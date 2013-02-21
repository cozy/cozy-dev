exec = require('child_process').exec
spawn = require('child_process').spawn


# Execute sequentially given shell commands until there is no more command left.
exports.execUntilEmpty = (commands, callback) ->
    command = commands.shift()

    exec command, (err, stdout, stderr) ->
        if err
            console.log stderr
        else if commands.length > 0
            exports.execUntilEmpty commands, callback
        else
            callback()


exports.spawnUntilEmpty = (commands, callback) ->
    commandDescriptor = commands.shift()

    command = spawn commandDescriptor.name, commandDescriptor.args

    command.stdout.on 'data',  (data) ->
        console.log "#{data}"

    command.stderr.on 'data', (data) ->
        console.log "#{data}"

    command.on 'exit', (code) ->
        if commands.length > 0
            exports.spawnUntilEmpty commands, callback
        else
            callback()

