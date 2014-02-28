fs     = require 'fs'
{exec} = require 'child_process'

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
    console.log "Compile coffee files to JS..."

    command = "coffee --compile --output lib/ src/ "
    exec command, (err, stdout, stderr) ->
        if err
            console.log "Running coffee-script compiler caught exception: \n" + err
            process.exit 1
        else
            console.log "Compilation succeeded."
            console.log stdout
            process.exit 0

task "lint", "Run coffeelint on source files", ->
    lintFiles = walk '.',  ['node_modules', 'tests']

    # if installed globally, output will be colored
    testCommand = "coffeelint -v"
    exec testCommand, (err, stdout, stderr) ->
        if err or stderr
            command = "./node_modules/coffeelint/bin/coffeelint"
        else
            command = "coffeelint"

        command += " -f coffeelint.json -r " + lintFiles.join " "
        exec command, (err, stdout, stderr) ->
            console.log stderr
            console.log stdout
