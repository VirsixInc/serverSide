fs = require('fs')
assert = require('assert')
mongoose = require('mongoose')
path = require('path')
multer = require('multer')

dbPort = 27017
dbHost = 'localhost'

supportedTemplates = [
  "cards",
  "buckets",
  "multiples",
  "sequences"
  ]

currentAssignments = []

studentCollection = "studentCollection"
imageDir = __dirname + "/../images/"

genericContentSchema = mongoose.Schema({
  indiArg: [],
})

studentSchema = mongoose.Schema({
  username: String,
  password: String,
  teacher: String,
  assignments: [],
})

termSchema = mongoose.Schema({
  termsPerStudent:[]
})

mongoose.connect('mongodb://localhost:27017/devryTestDB')
mongConnect = mongoose.connection
mongConnect.on('error', console.error.bind(console, 'connect error'))
mongConnect.on('open',(callback)->
  reset()
  console.log("DATABASE OPENED")
)



#ASSIGNMENT FUNCTIONS
#
#
#

reset = ()->
  mongConnect.db.collections((err,names)->
    for thisd in names
      for supported in supportedTemplates
        if thisd.s.name.indexOf(supported) > -1
          currentAssignments.push(thisd.s.name)
          currentAssignments.sort()
          break
  )

writeDatabaseContent = (arrayToWrite, fileName)->
  contentModel = mongoose.model(fileName, genericContentSchema)
  for argument in arrayToWrite
    do(argument)->
      currContentModel = new contentModel({indiArg:argument})
      contentModel.count({
        indiArg:currContentModel.indiArg
      }, (err, count)->
        if count < 1 && currContentModel.indiArg != undefined
          new contentModel(currContentModel).save()
          return true
        else
          console.log("Exists or is undefined")
          return true
        return false
      )

exports.uploadNewFile = (filePath, callback)->
  fileName = path.basename(filePath)
  if filePath.indexOf('csv') > -1
    parsedCSV = parseCSV(filePath)
    csvToDatabase(parsedCSV, fileName)
    for supported in supportedTemplates
      if fileName.indexOf(supported) > -1
        currentAssignments.push(fileName)
        break
    currentAssignments.sort()
  else if filePath.indexOf('images') > -1
    assignExists = false
    for currentAssign in currentAssignments
      if filePath.indexOf(currentAssign) > -1
        assignExists = true
        fs.rename(filePath, imageDir + fileName,(err)->
          if err
            console.log(err)
        )

        break
    if !assignExists
      fs.unlink(filePath,(err)->
        if err
          console.log(err)
        else
          console.log("FILE DELETED")
      )
  callback "Uploaded!"

#UTILITY FUNCTIONS
#
#
#
#

csvToDatabase = (arrayToWrite, fileName) ->
  fileName = fileName.split('.')[0]
  checkFile = fileName.split('_')[0]
  if supportedTemplates.indexOf(checkFile) > -1
    writeDatabaseContent(arrayToWrite, fileName)
  else if checkFile == "students"
    addStudentsFromCSV(arrayToWrite)
  else
    console.log "UNSUPPORTED TEMPLATE"

parseCSV = (filePath) ->
  fileData = fs.readFileSync(filePath, 'utf8')
  fileData = fileData.split('\n')
  arrayToReturn = []
  for i in [0..fileData.length-1] by 1
    arrayToReturn[i] = fileData[i].split(',')
  return arrayToReturn

#STUDENT BASED FUNCTIONS
#
#
#
#


addStudentsFromCSV = (parsedStudentCSV, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  for student in parsedStudentCSV
    do(student)->
      currStudent = new studentModel({
        username:student[0],
        password:student[1],
        teacher:"Kathy",#student[2],
        assignments:[]
      })
      studentModel.count({
        username:currStudent.username
      }, (err, count)->
        if count < 1 && currStudent.username != undefined
          new studentModel(currStudent).save()
          return true
        else
          console.log("Exists or is undefined")
          return true
        return false
      )



exports.addStudent = (teacher, username, password, callback) ->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if(username.length > 1 && password.length > 1)
    studentModel.count({username:username},(err, count)->
      if !count
        dataToWrite = new studentModel({
          username:username,
          password:password,
          teacher:teacher,
          assignments:[]
        })
        dataToWrite.save()
        callback "account created", dataToWrite
      else
        callback "account not created"
    )
  else
    callback "username is blank || password is blank"

exports.pullStudents = (teacherName,analytics, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  console.log(currentAssignments)
  teacherName = "Kathy"
  studentModel.find({teacher:teacherName}, '-_id -__v').sort([['username', 'ascending']]).exec( (err, results)->
    if err
      callback err
    else
      if !analytics
        callback {students:results, assignments:currentAssignments}
      else
        assignmentsCallBack = []
        for assignment in currentAssignments
          assignCb = "NULL"
          totalStudentsPlayed = 0
          totalTime = 0
          totalMastery = 0
          order = -1
          surveyLink = ""
          dispName = ""
          for student in results
            indexOfAssign = student.assignments.map((e)-> return e.assignmentName).indexOf(assignment)
            if indexOfAssign > -1
              timeToAdd = student.assignments[indexOfAssign].timeSpentOnAssign
              order = student.assignments[indexOfAssign].order
              surveyLink = student.assignments[indexOfAssign].survey
              dispName = student.assignments[indexOfAssign].dispName
              timeToAdd = timeToAdd.split(":")
              timeToAdd = parseInt(timeToAdd[0])*3600 +  parseInt(timeToAdd[1])*60 + parseInt(timeToAdd[2])
              if timeToAdd > 0
                totalStudentsPlayed++
              totalTime = totalTime + timeToAdd
              totalMastery = totalMastery + student.assignments[indexOfAssign].mastery
          assignCb = {
            assignName:assignment,
            order:order,
            dispName:dispName,
            survey:surveyLink,
            totalStudents:(totalStudentsPlayed),
            totalTime:formatSeconds(totalTime),
            totalMastery:totalMastery,
            mastAvg:totalMastery/results.length,
            timeSpentAvg:formatSeconds(totalTime/results.length)
          }
          assignmentsCallBack.push(assignCb)
        callback {students:results, assignments:assignmentsCallBack}

    return
  )
  return

exports.pullStudent = (teacherName, student, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  teacherName = "Kathy"
  studentModel.findOne({teacher:teacherName, username:student}, '-_id -__v').sort([['username', 'ascending']]).exec( (err, result)->
    if err
      callback err
    else
      callback {student:result, assignments:result.assignments}
    return
  )
  return

exports.logStudentIn = (studentName, password, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  studentModel.findOne({username:studentName, password:password},(err, doc)->
    if doc
      callback true
    else
      callback false
  )

exports.setAssignmentMastery = (assignmentName, student, mastery, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.findOne({username:student},(err, doc)->
      elementPos = doc.assignments.map((x) ->
        x.assignmentName
      ).indexOf(assignmentName)
      doc.assignments[elementPos].mastery = mastery
      doc.markModified('assignments')
      doc.save()
      callback doc
    )


exports.setAssignmentTime = (assignmentName, student, time, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.findOne({username:student},(err, doc)->
      elementPos = doc.assignments.map((x) ->
        x.assignmentName
      ).indexOf(assignmentName)
      doc.assignments[elementPos].timeSpentOnAssign = formatSeconds(time)
      doc.markModified('assignments')
      doc.save()
      callback doc
    )

exports.pullAssignmentMastery = (assignmentName, student, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.findOne({username:student},(err, doc)->
      elementPos = doc.assignments.map((x) ->
        x.assignmentName
      ).indexOf(assignmentName)
      doc.assignments[elementPos].mastery = mastery
      callback doc.assignments[elementPos].mastery
    )

formatSeconds = (seconds) ->
  date = new Date(1970, 0, 1)
  date.setSeconds seconds
  date.toTimeString().replace /.*(\d{2}:\d{2}:\d{2}).*/, '$1'



exports.addAssignmentToAllStudents = (assignmentName, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.find({},(err, docs)->
      docs.forEach((doc)->
        doesntExist = true
        for allAssigns in doc.assignments
          if allAssigns.assignmentName == assignmentName
            doesntExist = false
            break
        if doesntExist == true
          allImageFolders = fs.readdirSync(imageDir)
          hasImages = true
          for x in allImageFolders
            console.log(x)
            if x.indexOf(assignmentName) > -1
              hasImages = true
              console.log("HAS IMAGES!!!")
          console.log(hasImages)
          studentModel.findByIdAndUpdate(doc.id,
            {$push:{assignments:{assignmentName:assignmentName, mastery:0, timeSpentOnAssign:formatSeconds(0), hasImages:hasImages, terms:[], order:-1}}},(err, model) ->
              if err
                console.log err
              else
                console.log "LOGGING MODEL"
                console.log model
          )
        else
          console.log "exists!"
      )
      sortAssignments()
      callback ("Assignment added:" + assignmentName)
    )
  else
    callback "Assignment does not exist"

exports.pullTermMastery = (assignmentName, student, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.findOne({username:student},(err, doc)->
      exists = false
      for assign in doc.assignments
        if assign.assignmentName == assignmentName
          exists = true
          break
      if exists == true
        newArr = doc.assignments
        assignIndex = newArr.map((newArr) ->
          newArr.assignmentName
        ).indexOf assignmentName
        callback doc.assignments[assignIndex].terms
      else
        callback "NOT ASSIGNED"
    )
  else
    callback "ASSIGNMENT DOES NOT EXIST"

exports.setAssignmentSurvey = (assignmentName, survey, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.find({},(err, docs)->
      docs.forEach((doc)->
        exists = false
        for allAssigns in doc.assignments
          if allAssigns.assignmentName == assignmentName
            exists = true
            break
        if exists == true
          newArr = doc.assignments

          assignIndex = newArr.map((newArr) ->
            newArr.assignmentName
          ).indexOf assignmentName
          doc.assignments[assignIndex].survey = survey
          doc.markModified('assignments')
          doc.save((err)->
            if err
              callback err
            else
              callback "SUCCESS"
          )
        else
          console.log "exists!"
      )
      sortAssignments()
      callback ("Assignment added:" + assignmentName)
    )
  else
    callback "Assignment does not exist"

exports.setAssignmentName = (assignmentName, dispName, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.find({},(err, docs)->
      docs.forEach((doc)->
        exists = false
        for allAssigns in doc.assignments
          if allAssigns.assignmentName == assignmentName
            exists = true
            break
        if exists == true
          newArr = doc.assignments

          assignIndex = newArr.map((newArr) ->
            newArr.assignmentName
          ).indexOf assignmentName
          doc.assignments[assignIndex].dispName = dispName
          doc.markModified('assignments')
          doc.save((err)->
            if err
              callback err
            else
              callback "SUCCESS"
          )
        else
          console.log "exists!"
      )
      sortAssignments()
      callback ("Assignment added:" + assignmentName)
    )
  else
    callback "Assignment does not exist"

exports.setAssignmentOrder = (assignmentName, order, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.find({},(err, docs)->
      docs.forEach((doc)->
        exists = false
        for allAssigns in doc.assignments
          if allAssigns.assignmentName == assignmentName
            exists = true
            break
        if exists == true
          newArr = doc.assignments

          assignIndex = newArr.map((newArr) ->
            newArr.assignmentName
          ).indexOf assignmentName
          doc.assignments[assignIndex].order = order
          doc.markModified('assignments')
          doc.save((err)->
            if err
              callback err
            else
              callback "SUCCESS"
          )
        else
          console.log "exists!"
      )
      sortAssignments()
      callback ("Assignment added:" + assignmentName)
    )
  else
    callback "Assignment does not exist"

exports.setTermMastery = (assignmentName, student, content, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  console.log(content)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.findOne({username:student},(err, doc)->
      exists = false
      for assign in doc.assignments
        if assign.assignmentName == assignmentName
          exists = true
          break
      if exists == true
        contToUpload = content.split("|")
        newArr = doc.assignments
        for cont in contToUpload
          splitContent = cont.split(",")

          assignIndex = newArr.map((newArr) ->
            newArr.assignmentName
          ).indexOf assignmentName
          assignTerms = newArr[assignIndex].terms
          termIndex = assignTerms.map((assignTerms) ->
            assignTerms.term
          ).indexOf splitContent[0]
          term = splitContent[0]
          correct = parseInt(splitContent[1])
          incorrect = parseInt(splitContent[2])
          newTerm = {
            term:term,
            correct:correct,
            incorrect:incorrect}
          if termIndex > -1
            doc.assignments[assignIndex].terms[termIndex] = newTerm
          else
            doc.assignments[assignIndex].terms.push(newTerm)
        doc.markModified('assignments')
        doc.save((err)->
          console.log("SAVING")
          if err
            console.log(err)
            callback err
          else
            console.log("SUCCESS")
            callback "SUCCESS"
        )
      else
        callback "ASSIGN IS NOT ASSIGNED TO STUDENT"
      )
    sortAssignments()
  else
    callback "ASSIGN IS NOT IN DATABASE"

exports.pullStudentAssignments = (username, password, callback) ->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if(username.length > 1 && password.length > 1)
    studentModel.findOne({username:username},(err, doc)->
      callback doc.assignments
    )
  else
    callback "username is blank || password is blank"
    return true
  return

exports.pullStudentAssignment = (student, assignmentName, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.findOne({username:student},(err, doc)->
      exists = false
      for assign in doc.assignments
        if assign.assignmentName == assignmentName
          exists = true
          break
      if exists == true
        newArr = doc.assignments
        assignIndex = newArr.map((newArr) ->
          newArr.assignmentName
        ).indexOf assignmentName
        callback doc.assignments[assignIndex].terms
      else
        callback "NOT ASSIGNED"
    )
  else
    callback "ASSIGNMENT DOES NOT EXIST"

exports.pullAssignment = (collectionName, callback) ->
  console.log("PULLING ASSIGN")
  sortAssignments()
  console.log(collectionName)
  readFromDatabase(collectionName, genericContentSchema, (dataToReturn)->
    callback dataToReturn
  )
  return

sortAssignments = ()->
  studentModel = mongoose.model(studentCollection, studentSchema)
  studentModel.find({},(err, docs)->
    if !err
      for doc in docs
        doc.assignments = doc.assignments.sort(compare)
        currentAssignments = currentAssignments.sort()
        doc.markModified('assignments')
        doc.save()
      return true
    else
      return err
  )

compare = (a, b) ->
  if a.assignmentName < b.assignmentName
    return -1
  if a.assignmentName > b.assignmentName
    return 1
  0

readFromDatabase = (collectionName, schema, callback)->
  modelToRead = mongoose.model(collectionName, schema, collectionName)
  modelToRead.find({},'-_id -__v', (err, fullCollection)->
    if err
      callback err
    else
      callback fullCollection
  )
  return
