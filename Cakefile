{exec, spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'

lastChange = {}

coffee = ('src/coffee/' + s for s in \
    ['connect.coffee', 'cruncher.coffee', 'docs.coffee', 'charts.coffee',
     'graphs.coffee', 'highlight.coffee', 'line-state.coffee', 'number-widget.coffee',
     'scrubbing.coffee', 'solver.coffee', 'util.coffee', 'value.coffee'])
jison = ['src/jison/parser.jison']
less = ['src/less/cruncher.less']
test = ('test/' + s for s in ['solver.coffee'])

coffeeOut = 'bin/js'
jisonOut = 'bin/js'
lessOut = 'bin/css'

compileCoffee = (file) ->
    exec "coffee -o #{coffeeOut} -c #{file}", (err, stdout, stderr) ->
        return console.error err if err
        console.log "Compiled #{file}"

compileJison = (file) ->
    exec "jison -o #{jisonOut}/#{path.basename(file, '.jison')}.js #{file}", (err, stdout, stderr) ->
        return console.error err if err
        console.log "Compiled #{file}"

compileLess = (file) ->
    exec "lessc #{file} #{lessOut}/#{path.basename(file, '.less')}.css", (err, stdout, stderr) ->
        return console.error err if err
        console.log "Compiled #{file}"
 
watchFile = (file, fn) ->
    try
        fs.watch file, (event, filename) ->
            return if event isnt 'change'
            # ignore repeated event misfires
            fn file if Date.now() - lastChange[file] > 1000
            lastChange[file] = Date.now()
    catch e
        console.log "Error watching #{file}"
 
watchFiles = (files, fn) ->
    for file in files
        lastChange[file] = 0
        watchFile file, fn
        console.log "Watching #{file}"

task 'build:watch', 'Build, then watch', ->
    invoke 'build'
    invoke 'watch'

task 'build', 'Compile *.coffee, *.jison and *.less', ->
    compileCoffee(f) for f in coffee
    compileJison(f) for f in jison
    compileLess(f) for f in less
 
task 'watch', 'Compile + watch *.coffee, *.jison and *.less', ->
    watchFiles coffee, compileCoffee
    watchFiles jison, compileJison
    watchFiles less, compileLess
 
task 'watch:js', 'Compile + watch *.coffee only', ->
    watchFiles coffee, compileCoffee

task 'watch:jison', 'Compile + watch *.jison only', ->
    watchFiles jison, compileJison

task 'watch:css', 'Compile + watch *.less only', ->
    watchFiles less, compileLess

task 'test', 'Test with Casper', ->
    casper = spawn 'casperjs', ['test'].concat(test)
    casper.stdout.pipe process.stdout
    casper.stderr.pipe process.stderr
