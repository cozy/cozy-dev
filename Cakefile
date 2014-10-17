fs     = require 'fs'
{exec} = require 'child_process'
log = require('printit')
        prefix: 'cake'

walk = (dir, excludeElements = []) ->
    fileList = []
    list = fs.readdirSync dir
    if list
        for file in list
            if file and file not in excludeElements
                filename = "#{dir}/#{file}"
                stat = fs.statSync filename
                if stat and stat.isDirectory()
                    fileList = fileList.concat walk filename, excludeElements
                else if filename.substr(-6) is "coffee"
                    fileList.push filename
    return fileList

task "build", "Compile coffee files to JS", ->
    log.info "Compile coffee files to JS..."

    command = "coffee --compile --output lib/ src/ "
    exec command, (err, stdout, stderr) ->
        if err
            log.error "Running coffee-script compiler caught exception:\n#{err}"
            process.exit 1
        else
            log.info "Compilation succeeded."
            process.exit 0

task "lint", "Run coffeelint on source files", ->
    lintFiles = walk '.',  ['node_modules', 'tests']

    testCommand = "coffeelint -v"
    exec testCommand, (err, stdout, stderr) ->
        if err? or stderr?
            command = "./node_modules/coffeelint/bin/coffeelint"
        else
            command = "coffeelint"

        command += " -f coffeelint.json -r " + lintFiles.join " "
        exec command, (err, stdout, stderr) ->
            log.info stdout
