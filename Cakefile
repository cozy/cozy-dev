fs = require 'fs'
{exec} = require 'child_process'

task "build", "", ->
  console.log "Compile main file..."
  command = "coffee -c lib/main.coffee"
  exec command, (err, stdout, stderr) ->
    if err
      console.log "Running coffee-script compiler caught exception: \n" + err
    else
      console.log "Compilation succeeds."
      
    console.log stdout
