{exec, spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'

lastChange = {}

staticPaths = ['res', 'lib', 'index.html']

js = ('src/coffee/' + s for s in \
    ['connect.js', 'cruncher.js', 'docs.js', 'charts.js',
     'graphs.js', 'highlight.js', 'line-state.js', 'number-widget.js',
     'scrubbing.js', 'solver.js', 'util.js', 'value.js'])
jison = ['src/jison/parser.jison']
less = ['src/less/cruncher.less']
test = ('test/' + s for s in ['solver.coffee'])

babelOut = 'public/js'
jisonOut = 'public/js'
lessOut = 'public/css'

compileCoffee = (file) ->
    basename = file.split('/')[-1]
    exec "babel -s -o #{babelOut}/#{basename} #{file}", (err, stdout, stderr) ->
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

copyStaticFile = (file) ->
    exec "cp -r #{file} public/", (err, stdout, stderr) ->
         return console.error err if err
         console.log "Copied #{file}"

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

watchStaticPath = (path) ->
    console.log "Watching #{path}"
    if fs.lstatSync(path).isDirectory()
        watch.watchTree path, (file, curr, prev) ->
            return if typeof file is 'object' && prev is null && curr is null
            copyStaticFile file
    else
        watchFile path, copyStaticFile

task 'build:watch', 'Build, then watch', ->
    invoke 'build'
    invoke 'watch'

task 'build', 'Compile *.coffee, *.jison and *.less', ->
    compileCoffee(f) for f in js
    compileJison(f) for f in jison
    compileLess(f) for f in less
    for staticPath in staticPaths
        do (staticPath) -> copyStaticFile staticPath
 
task 'watch', 'Compile + watch *.coffee, *.jison and *.less', ->
    watchFiles coffee, compileCoffee
    watchFiles jison, compileJison
    watchFiles less, compileLess
    watchStaticPath path for path in staticPaths
 
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
