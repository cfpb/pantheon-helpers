# copyright David Greisen licensed under Apache License v 2.0
# derived from code from ShareJS https://github.com/share/ShareJS (MIT)
{exec} = require 'child_process'
{proxyExec} = require('./lib/utils')
path = require('path')
fs = require('fs')
Promise = require('./lib/promise')

DIR = __dirname

task 'build', 'Build the .js files', (options) ->
  console.log('Compiling Coffee from src to lib')
  proxyExec("coffee --compile --output ./lib/ ./src/", process)

task 'watch', 'Watch src directory and build the .js files', (options) ->
  console.log('Watching Coffee in src and compiling to lib')
  proxyExec("coffee --watch --output ./lib/ ./src/", process)

option '-v', '--verbose', 'verbose testing output'
option '-s', '--spec-only', 'run specs without coverage'
task 'test', 'run all tests', (options) ->
  cmd = "./node_modules/iced-coffee-script/bin/coffee --bare --compile --output ./spec/ ./spec/"
  proxyExec(cmd, process, () -> 
    cmd = if options['spec-only'] then "" else "./node_modules/istanbul/lib/cli.js cover "
    cmd += "./node_modules/jasmine-node/bin/jasmine-node ./spec"
    cmd += if options.verbose then "--verbose " else ""
    cmd += " ./spec/"
    proxyExec(cmd, process, (code) -> process.exit(code))
  )
