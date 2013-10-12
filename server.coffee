config = require('./config.js').config
express = require 'express'
fs = require 'fs'
path = require 'path'
eco = require 'eco'
io = require('socket.io').listen config.sockets_port
log4js = require('log4js')
log4js.replaceConsole()

socket = null
timeline = null
clockTimerID = null
startTime = null

io.enable 'browser client minification'         # send minified client
io.enable 'browser client etag'                 # apply etag caching logic based on version number
io.enable 'browser client gzip'                 # gzip the file
io.set 'log level', config.log_level
io.set 'transports', config.transports

server = express()

server.configure ->
    server.use '/static', express.static path.join(__dirname, '/static')
    server.use express.bodyParser()
    server.use (req, res, next) ->
        res.header 'Access-Control-Allow-Origin', config.allowedDomains
        res.header 'Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE'
        res.header 'Access-Control-Allow-Headers', 'Content-Type'
        next()

server.get '/', (req, res) ->
    template = fs.readFileSync path.join(__dirname + "/index.eco.html"), "utf-8"
    context = {}
    res.send eco.render template, context


server.post '/start', (req, res) ->
    startTimeline()


startTimeline = ->
    clearInterval(clockTimerID)
    clockTimerID = setInterval clockTick, 40 # 25 frames/s

    startTime = +new Date()
    clockTick()


clockTick = ->
    time = (new Date() - startTime) / 1000
    #console.log "tick #{time}s"

    # check queue points in timeline
    for point in timeline
        if not point.passed and point.time < time
            onPoint(point)

onPoint = (point) ->
    point.passed = true
    console.log "point " + point.time



createTimeline = ->
    program_info = JSON.parse fs.readFileSync path.join(__dirname + "/static/program_info.json"), "utf-8"
    timeline = []

    console.log "createTimeline"

    for question in program_info.questions
        soon_point = {
            type: "question:soon"
            time: Math.max 0, question.start - 2
            buttons: []
            passed:false
        }

        start_point = {
            type: "question:start"
            time: question.start
            buttons: question.buttons
            passed: false
            countdown: question.end - question.start
        }

        end_point = {
            type: "question:end"
            time: question.end
            buttons: []
            passed:false
        }

        timeline.push soon_point
        timeline.push start_point
        timeline.push end_point

    console.log timeline

createTimeline()
startTimeline()

console.log "http server running on port " + config.server_port
console.log "sockets server running on port " + config.sockets_port
server.listen config.server_port
