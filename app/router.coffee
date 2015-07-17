CT = require('./modules/country-list')
AM = require('./modules/account-manager')
EM = require('./modules/email-dispatcher')
dbHandle = require('./modules/dbHandling')
url = require('url')
multer = require('multer')
fs = require('fs')
request = require('request')

module.exports = (app) ->

#CLIENT SIDE
#
#
#

  app.get '/client/images?*', (req,res)->
    res.download(__dirname + '/images/' + req.query.assignment)
    return

  app.get '/client/pullData?*', (req, res)->
    dbHandle.pullStudentAssignments req.query.username, req.query.password, (assignmentList)->
      res.send(assignmentList)
    return

  app.get '/client/pullAssignment?*', (req, res)->
    dbHandle.pullAssignment req.query.assign, (assignToReturn)->
      res.send(assignToReturn)
    return

  app.get '/client/pullAssignmentInfo?*', (req, res)->
    dbHandle.pullAssignmentInfo req.query.assign, req.query.username, req.query.password (assignToReturn)->
      res.send(assignToReturn)
    return

  app.get '/client/logStudentIn?*', (req, res)->
    dbHandle.logStudentIn req.query.username, req.query.password, (results)->
      res.send(results)
    return

  app.get '/client/setAssignmentMastery?*', (req, res)->
    dbHandle.setAssignmentMastery req.query.assignmentName, req.query.student, req.query.mastery, (results)->
      res.send(results)

  app.get '/client/setAssignmentTime?*', (req, res)->
    dbHandle.setAssignmentTime req.query.assignmentName, req.query.student, req.query.time, (results)->
      res.send(results)

#FRONT END WEB
#
#
#

  app.get '/home/addAssignmentToStudents?*', (req, res)->
    if req.session.user == undefined
      res.redirect '/'
    else
      console
      dbHandle.addAssignmentToAllStudents req.query.assignmentName, (results)->
        res.send(results)

  app.get '/home/addStudent?*', (req, res)->
    if req.session.user == undefined
      res.redirect '/'
    else
      dbHandle.addStudent req.query.teacher, req.query.username, req.query.password, (results)->
        res.send(results)

  app.get '/home/addAssignment', (req, res) ->
    res.render 'assignments'

  app.get '/home/listStudents', (req, res) ->
    dbHandle.pullStudents("Kathy", (results)->
      if results != undefined
        res.render 'trackStudents',
          title: 'All students'
          students: results.students
          assignments: results.assignments
      else
        res.write '<p> no students </p>'
      return
    )
    return

  app.post '/api/upload',(req,res)->
    fileName = req.files.csvToUpload.name
    filePath = req.files.csvToUpload.path
    newPath = __dirname + "/uploads/" + fileName
    fs.createReadStream(filePath)
      .pipe(fs.createWriteStream(__dirname + "/uploads/" + fileName))
      .on('close', ()->
        dbHandle.uploadNewFile(newPath, (results)->
          console.log(results)
        )
      )
    ###
    fs.readFile(filePath,"utf8", (err, data)->
      newPath = __dirname + "/uploads/" + fileName
      checkFile = fileName.split('.')[1]

      fs.writeFile(newPath, data, (err)->
        if err
        else
          dbHandle.uploadNewFile(newPath, (results)->
            console.log(results)
          )
      )
    )
    ###
    res.redirect '/home/addAssignment'

  app.get '/', (req, res) ->

    # check if the user's credentials are saved in a cookie //
    if req.cookies.user == undefined or req.cookies.pass == undefined
      console.log("USER OR PASSWORD IS UNDEFINED")
      res.render 'login', title: 'Hello - Please Login To Your Account'
    else
      console.log("USER AND PASSWORD IS DEFINED")
      # attempt automatic login //
      AM.autoLogin req.cookies.user, req.cookies.pass, (o) ->
        if o != null
          req.session.user = o
          res.redirect '/home'
        else
          res.render 'login', title: 'Hello - Please Login To Your Account'
        return
    return

  app.post '/', (req, res) ->
    AM.manualLogin req.param('user'), req.param('pass'), (e, o) ->
      if !o
        console.log("O IS FALSE")
        res.send e, 400
      else
        console.log("O IS TRUE")
        req.session.user = o
        if req.param('remember-me') == 'true'
          res.cookie 'user', o.user, maxAge: 900000
          res.cookie 'pass', o.pass, maxAge: 900000
        res.send o, 200
      return
    return
  # logged-in user homepage //
  app.get '/home', (req, res) ->
    if req.session.user == null
      # if user is not logged-in redirect back to login page //
      res.redirect '/'
    else
      res.redirect '/home/listStudents'
    return


  app.post '/home', (req, res) ->
    if req.param('user') != undefined
      AM.updateAccount {
        user: req.param('user')
        name: req.param('name')
        email: req.param('email')
        country: req.param('country')
        pass: req.param('pass')
      }, (e, o) ->
        if e
          res.send 'error-updating-account', 400
        else
          req.session.user = o
          # update the user's login cookies if they exists //
          if req.cookies.user != undefined and req.cookies.pass != undefined
            res.cookie 'user', o.user, maxAge: 900000
            res.cookie 'pass', o.pass, maxAge: 900000
          res.send 'ok', 200
        return
    else if req.param('logout') == 'true'
      res.clearCookie 'user'
      res.clearCookie 'pass'
      req.session.destroy (e) ->
        res.send 'ok', 200
        return
    return

  # creating new accounts //
  app.get '/signup', (req, res) ->
    res.render 'signup',
      title: 'Signup'
      countries: CT
    return
  app.post '/signup', (req, res) ->
    AM.addNewAccount {
      name: req.param('name')
      email: req.param('email')
      user: req.param('user')
      pass: req.param('pass')
      country: req.param('country')
    }, (e) ->
      if e
        res.send e, 400
      else
        res.send 'ok', 200
      return
    return
  # password reset //
  app.post '/lost-password', (req, res) ->
    # look up the user's account via their email //
    AM.getAccountByEmail req.param('email'), (o) ->
      if o
        res.send 'ok', 200
        EM.dispatchResetPasswordLink o, (e, m) ->
          # this callback takes a moment to return //
          # should add an ajax loader to give user feedback //
          if !e
            #	res.send('ok', 200);
          else
            res.send 'email-server-error', 400
            for k of e
              console.log 'error : ', k, e[k]
          return
      else
        res.send 'email-not-found', 400
      return
    return

  app.get '/reset-password', (req, res) ->
    email = req.query['e']
    passH = req.query['p']
    AM.validateResetLink email, passH, (e) ->
      if e != 'ok'
        res.redirect '/'
      else
        # save the user's email in a session instead of sending to the client //
        req.session.reset =
          email: email
          passHash: passH
        res.render 'reset', title: 'Reset Password'
      return
    return

  app.post '/reset-password', (req, res) ->
    nPass = req.param('pass')
    # retrieve the user's email from the session to lookup their account and reset password //
    email = req.session.reset.email
    # destory the session immediately after retrieving the stored email //
    req.session.destroy()
    AM.updatePassword email, nPass, (e, o) ->
      if o
        res.send 'ok', 200
      else
        res.send 'unable to update password', 400
      return
    return
  # view & delete accounts //
  app.get '/print', (req, res) ->
    AM.getAllRecords (e, accounts) ->
      res.render 'print',
        title: 'Account List'
        accts: accounts
      return
    return

  app.post '/delete', (req, res) ->
    AM.deleteAccount req.body.id, (e, obj) ->
      if !e
        res.clearCookie 'user'
        res.clearCookie 'pass'
        req.session.destroy (e) ->
          res.send 'ok', 200
          return
      else
        res.send 'record not found', 400
      return
    return
  app.get '/reset', (req, res) ->
    AM.delAllRecords ->
      res.redirect '/print'
      return
    return
  app.get '*', (req, res) ->
    res.render '404', title: 'Page Not Found'
    return
  return
