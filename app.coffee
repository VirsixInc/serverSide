###*
	* Node.js Login Boilerplate
	* More Info : http://bit.ly/LsODY8
	* Copyright (c) 2013 Stephen Braitsch
*
###

express = require('express')
http = require('http')
bodyParser = require('body-parser')
multer = require('multer')
app = express()
app.configure ->
  app.set 'port', 8000
  app.set 'views', __dirname + '/app/views'
  app.set 'view engine', 'jade'
  app.set 'view options',{layout:false}
  app.locals.pretty = true
  app.use bodyParser.urlencoded({extended:true})
  app.use express.cookieParser()
  app.use express.session(secret: 'super-duper-secret-secret')
  app.use express.methodOverride()
  app.use express.multipart()
  app.use express.static(__dirname + '/dist/')
  return
app.configure 'development', ->
  app.use express.errorHandler()
  return
require('./app/router') app
http.createServer(app).listen app.get('port'), ->
  console.log 'Express server listening on port ' + app.get('port')
  return
