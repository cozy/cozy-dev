exec = require('child_process').exec

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
