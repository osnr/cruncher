spawn = (require 'child_process').spawn

to_stdio = (emitter) ->
    emitter.stdout.on 'data', (data) -> process.stdout.write data
    emitter.stderr.on 'data', (data) -> process.stderr.write data
    emitter

task 'build:watch', 'Build and then watch .coffee files', (options) ->
    to_stdio spawn 'coffee', ['--watch', '--compile', '--output', 'bin', 'src']

task 'build:parser', 'Build the math parser', (options) ->
    to_stdio spawn 'jison', ['src/parser.jison', '-o', 'bin/parser.js']

task 'build', 'Build all', (options) ->
    invoke 'build:parser'
    to_stdio spawn 'coffee', ['--compile', '--output', 'bin', 'src']
