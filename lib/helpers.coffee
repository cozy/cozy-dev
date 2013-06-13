exec = require('child_process').exec
spawn = require('child_process').spawn
util = require 'util'


# Execute sequentially given shell commands with "exec"
# until there is no more command left. Exec displays the output at the end.
exports.execUntilEmpty = (commands, callback) ->
    command = commands.shift()

    exec command, (err, stdout, stderr) ->
        if err
            console.log stderr
        else if commands.length > 0
            exports.execUntilEmpty commands, callback
        else
            callback()

# Execute sequentially given shell commands with "spawn"
# until there is no more command left. Spawn displays the output as it comes.
exports.spawnUntilEmpty = (commands, callback) ->
    commandDescriptor = commands.shift()

    command = spawn(commandDescriptor.name, commandDescriptor.args,
                    commandDescriptor.opts)

    command.stdout.on 'data',  (data) ->
        util.print "#{data}"

    command.stderr.on 'data', (data) ->
        util.print "#{data}"

    command.on 'exit', (code) ->
        if commands.length > 0
            exports.spawnUntilEmpty commands, callback
        else
            callback()

