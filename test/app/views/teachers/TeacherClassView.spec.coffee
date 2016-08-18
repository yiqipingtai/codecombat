TeacherClassView = require 'views/courses/TeacherClassView'
storage = require 'core/storage'
forms = require 'core/forms'
factories = require 'test/app/factories'
Users = require 'collections/Users'
Courses = require 'collections/Courses'
Levels = require 'collections/Levels'
LevelSessions = require 'collections/LevelSessions'
CourseInstances = require 'collections/CourseInstances'
Prepaids = require 'collections/Prepaids'

describe '/teachers/classes/:handle', ->
  
describe 'TeacherClassView', ->
  
  # describe 'when logged out', ->
  #   it 'responds with 401 error'
  #   it 'shows Log In and Create Account buttons'
  
  # describe "when you don't own the class", ->
  #   it 'responds with 403 error'
  #   it 'shows Log Out button'
    
  describe 'when logged in', ->
    beforeEach (done) ->
      me = factories.makeUser({})
      
      @courses = new Courses([
        factories.makeCourse({name: 'First Course'}),
        factories.makeCourse({name: 'Second Course'}),
        factories.makeCourse({name: 'Beta Course', releasePhase: 'beta'}),
      ])
      @releasedCourses = new Courses(@courses.where({ releasePhase: 'released' }))
      @available1 = factories.makePrepaid({maxRedeemers: 1})
      @available2 = factories.makePrepaid({maxRedeemers: 1})
      expired = factories.makePrepaid({endDate: moment().subtract(1, 'day').toISOString()})
      @prepaids = new Prepaids([@available1, @available2, expired])
      @students = new Users([
        factories.makeUser({name: 'Abner'})
        factories.makeUser({name: 'Abigail'})
        factories.makeUser({name: 'Abby'}, {prepaid: @available1})
        factories.makeUser({name: 'Ben'}, {prepaid: @available1})
        factories.makeUser({name: 'Ned'}, {prepaid: expired})
        factories.makeUser({name: 'Ebner'}, {prepaid: expired})
      ])
      @levels = new Levels(_.times(2, -> factories.makeLevel({ concepts: ['basic_syntax', 'arguments', 'functions'] })))
      @levels.push(factories.makeLevel({ concepts: ['basic_syntax', 'arguments', 'functions'], primerLanguage: 'javascript' }))

      _.defer done

    describe 'when python classroom', ->
      beforeEach (done) ->
        @classroom = factories.makeClassroom({ aceConfig: { language: 'python' }}, { courses: @releasedCourses, members: @students, levels: [@levels, new Levels()] })
        @courseInstances = new CourseInstances([
          factories.makeCourseInstance({}, { course: @releasedCourses.first(), @classroom, members: @students })
          factories.makeCourseInstance({}, { course: @releasedCourses.last(), @classroom, members: @students })
        ])

        sessions = []
        @finishedStudent = @students.first()
        @unfinishedStudent = @students.last()
        for level in @levels.models
          sessions.push(factories.makeLevelSession(
              {state: {complete: true}, playtime: 60},
              {level, creator: @finishedStudent})
          )
        sessions.push(factories.makeLevelSession(
            {state: {complete: true}, playtime: 60},
            {level: @levels.first(), creator: @unfinishedStudent})
        )
        @levelSessions = new LevelSessions(sessions)

        @view = new TeacherClassView({}, @courseInstances.first().id)
        @view.classroom.fakeRequests[0].respondWith({ status: 200, responseText: @classroom.stringify() })
        @view.courses.fakeRequests[0].respondWith({ status: 200, responseText: @courses.stringify() })
        @view.courseInstances.fakeRequests[0].respondWith({ status: 200, responseText: @courseInstances.stringify() })
        @view.students.fakeRequests[0].respondWith({ status: 200, responseText: @students.stringify() })
        @view.classroom.sessions.fakeRequests[0].respondWith({ status: 200, responseText: @levelSessions.stringify() })
        @view.levels.fakeRequests[0].respondWith({ status: 200, responseText: @levels.stringify() })
        @view.prepaids.fakeRequests[0].respondWith({ status: 200, responseText: @prepaids.stringify() })

        jasmine.demoEl(@view.$el)
        _.defer done

      it 'has contents', ->
        expect(@view.$el.children().length).toBeGreaterThan(0)

      # it "shows the classroom's name and description"
      # it "shows the classroom's join code"
      
      describe 'the Students tab', ->
        beforeEach (done) ->
          @view.state.set('activeTab', '#students-tab')
          _.defer(done)

        # it 'shows all of the students'
        # it 'sorts correctly by Name'
        # it 'sorts correctly by Progress'
        
        describe 'bulk-assign controls', ->
          it 'shows alert when assigning course 2 to unenrolled students', (done) ->
            expect(@view.$('.cant-assign-to-unenrolled').hasClass('visible')).toBe(false)
            @view.$('.student-row .checkbox-flat').click()
            @view.$('.assign-to-selected-students').click()
            _.defer =>
              expect(@view.$('.cant-assign-to-unenrolled').hasClass('visible')).toBe(true)
              done()
            
          it 'shows alert when assigning but no students are selected', (done) ->
            expect(@view.$('.no-students-selected').hasClass('visible')).toBe(false)
            @view.$('.assign-to-selected-students').click()
            _.defer =>
              expect(@view.$('.no-students-selected').hasClass('visible')).toBe(true)
              done()
      
      # describe 'the Course Progress tab', ->
      #   it 'shows the correct Course Overview progress'
      #
      #   describe 'when viewing another course'
      #     it 'still shows the correct Course Overview progress'
      #
      
      describe 'the Enrollment Status tab', ->
        beforeEach ->
          @view.state.set('activeTab', '#enrollment-status-tab')
        
        describe 'Enroll button', ->
          it 'calls enrollStudents with that user when clicked', ->
            spyOn(@view, 'enrollStudents')
            @view.$('.enroll-student-button:first').click()
            expect(@view.enrollStudents).toHaveBeenCalled()
            users = @view.enrollStudents.calls.argsFor(0)[0]
            expect(users.size()).toBe(1)
            expect(users.first().id).toBe(@view.students.first().id)

      describe 'Export Student Progress (CSV) button', ->
        it 'downloads a CSV file', ->
          spyOn(window, 'open').and.callFake (encodedCSV) =>
            progressData = decodeURI(encodedCSV)
            CSVHeader = 'data:text\/csv;charset=utf-8,'
            expect(progressData).toMatch new RegExp('^' + CSVHeader)
            lines = progressData.slice(CSVHeader.length).split('\n')
            expect(lines.length).toBe(@students.length + 1)
            for line in lines
              simplerLine = line.replace(/"[^"]+"/g, '""')
              # Username,Email,Total Playtime, [CS1-? Playtime], Concepts
              expect(simplerLine.match(/[^,]+/g).length).toBe(3 + @releasedCourses.length + 1)
              if simplerLine.match new RegExp(@finishedStudent.get('email'))
                expect(simplerLine).toMatch /3 minutes,3 minutes,0/
              else if simplerLine.match new RegExp(@unfinishedStudent.get('email'))
                expect(simplerLine).toMatch /a minute,a minute,0/
              else if simplerLine.match /@/
                expect(simplerLine).toMatch /0,0,0/
            return true
          @view.$('.export-student-progress-btn').click()
          expect(window.open).toHaveBeenCalled()

    describe 'when javascript classroom', ->
      beforeEach (done) ->
        @classroom = factories.makeClassroom({ aceConfig: { language: 'javascript' }}, { courses: @releasedCourses, members: @students, levels: [@levels, new Levels()]})
        @courseInstances = new CourseInstances([
          factories.makeCourseInstance({}, { course: @releasedCourses.first(), @classroom, members: @students })
          factories.makeCourseInstance({}, { course: @releasedCourses.last(), @classroom, members: @students })
        ])

        sessions = []
        @finishedStudent = @students.first()
        @unfinishedStudent = @students.last()
        classLanguage = @classroom.get('aceConfig')?.language
        for level in @levels.models
          continue if classLanguage and classLanguage is level.get('primerLanguage') 
          sessions.push(factories.makeLevelSession(
              {state: {complete: true}, playtime: 60},
              {level, creator: @finishedStudent})
          )
        sessions.push(factories.makeLevelSession(
            {state: {complete: true}, playtime: 60},
            {level: @levels.first(), creator: @unfinishedStudent})
        )
        @levelSessions = new LevelSessions(sessions)

        @view = new TeacherClassView({}, @courseInstances.first().id)
        @view.classroom.fakeRequests[0].respondWith({ status: 200, responseText: @classroom.stringify() })
        @view.courses.fakeRequests[0].respondWith({ status: 200, responseText: @courses.stringify() })
        @view.courseInstances.fakeRequests[0].respondWith({ status: 200, responseText: @courseInstances.stringify() })
        @view.students.fakeRequests[0].respondWith({ status: 200, responseText: @students.stringify() })
        @view.classroom.sessions.fakeRequests[0].respondWith({ status: 200, responseText: @levelSessions.stringify() })
        @view.levels.fakeRequests[0].respondWith({ status: 200, responseText: @levels.stringify() })
        @view.prepaids.fakeRequests[0].respondWith({ status: 200, responseText: @prepaids.stringify() })

        jasmine.demoEl(@view.$el)
        _.defer done

      describe 'Export Student Progress (CSV) button', ->
        it 'downloads a CSV file', ->
          spyOn(window, 'open').and.callFake (encodedCSV) =>
            progressData = decodeURI(encodedCSV)
            CSVHeader = 'data:text\/csv;charset=utf-8,'
            expect(progressData).toMatch new RegExp('^' + CSVHeader)
            lines = progressData.slice(CSVHeader.length).split('\n')
            expect(lines.length).toBe(@students.length + 1)
            for line in lines
              simplerLine = line.replace(/"[^"]+"/g, '""')
              # Username,Email,Total Playtime, [CS1-? Playtime], Concepts
              expect(simplerLine.match(/[^,]+/g).length).toBe(3 + @releasedCourses.length + 1)
              if simplerLine.match new RegExp(@finishedStudent.get('email'))
                expect(simplerLine).toMatch /2 minutes,2 minutes,0/
              else if simplerLine.match new RegExp(@unfinishedStudent.get('email'))
                expect(simplerLine).toMatch /a minute,a minute,0/
              else if simplerLine.match /@/
                expect(simplerLine).toMatch /0,0,0/
            return true
          @view.$('.export-student-progress-btn').click()
          expect(window.open).toHaveBeenCalled()

  
    fdescribe '.assignCourse(courseID, members)', ->
      beforeEach (done) ->
        @classroom = factories.makeClassroom({ aceConfig: { language: 'javascript' }}, { courses: @releasedCourses, members: @students, levels: [@levels, new Levels()]})
        @courseInstances = new CourseInstances([
          factories.makeCourseInstance({}, { course: @releasedCourses.first(), @classroom, members: @students })
          factories.makeCourseInstance({}, { course: @releasedCourses.last(), @classroom, members: @students })
        ])
  
        sessions = []
        @finishedStudent = @students.first()
        @unfinishedStudent = @students.last()
        classLanguage = @classroom.get('aceConfig')?.language
        for level in @levels.models
          continue if classLanguage and classLanguage is level.get('primerLanguage')
          sessions.push(factories.makeLevelSession(
              {state: {complete: true}, playtime: 60},
              {level, creator: @finishedStudent})
          )
        sessions.push(factories.makeLevelSession(
            {state: {complete: true}, playtime: 60},
            {level: @levels.first(), creator: @unfinishedStudent})
        )
        @levelSessions = new LevelSessions(sessions)
  
        @view = new TeacherClassView({}, @courseInstances.first().id)
        @view.classroom.fakeRequests[0].respondWith({ status: 200, responseText: @classroom.stringify() })
        @view.courses.fakeRequests[0].respondWith({ status: 200, responseText: @courses.stringify() })
        @view.courseInstances.fakeRequests[0].respondWith({ status: 200, responseText: @courseInstances.stringify() })
        @view.students.fakeRequests[0].respondWith({ status: 200, responseText: @students.stringify() })
        @view.classroom.sessions.fakeRequests[0].respondWith({ status: 200, responseText: @levelSessions.stringify() })
        @view.levels.fakeRequests[0].respondWith({ status: 200, responseText: @levels.stringify() })
        @view.prepaids.fakeRequests[0].respondWith({ status: 200, responseText: @prepaids.stringify() })
  
        jasmine.demoEl(@view.$el)
        _.defer done
      
      describe 'when no course instance exists for the given course', ->
        beforeEach (done) ->
          @view.courseInstances.reset()
          @view.assignCourse(@courses.first().id, @students.pluck('_id').slice(0, 1))
          @view.courseInstances.wait('add').then(done)

        it 'creates the missing course instance', ->
          request = jasmine.Ajax.requests.mostRecent()
          expect(request.method).toBe('POST')
          expect(request.url).toBe('/db/course_instance')

        it 'shows a noty if the course instance request fails', (done) ->
          request = jasmine.Ajax.requests.mostRecent()
          request.respondWith({
            status: 500,
            responseText: JSON.stringify({ message: "Internal Server Error" })
          })
          spyOn(window, 'noty').and.callFake(done)

      describe 'when the course is not free and some students are not enrolled', ->
        beforeEach (done) ->
          # first two students are unenrolled
          @view.assignCourse(@courses.first().id, @students.pluck('_id').slice(0, 2))
          @view.wait('begin-redeem-for-assign-course').then(done)

        it 'enrolls all unenrolled students', (done) ->
          numberOfRequests = _(@view.prepaids.models)
          .map((prepaid) -> prepaid.fakeRequests.length)
          .reduce((num, value) -> num + value)
          expect(numberOfRequests).toBe(2)
          done()

        it 'shows a noty if a redeem request fails', (done) ->
          request = jasmine.Ajax.requests.mostRecent()
          request.respondWith({
            status: 500,
            responseText: JSON.stringify({ message: "Internal Server Error" })
          })
          spyOn(window, 'noty').and.callFake(done)

      describe 'when there are not enough licenses available', ->
        beforeEach (done) ->
          # first four students are unenrolled, but only two licenses are available
          @view.assignCourse(@courses.first().id, @students.pluck('_id'))
          spyOn(@view, 'openModalView').and.callFake(done)

        it 'shows CoursesNotAssignedModal', ->
          expect(@view.openModalView).toHaveBeenCalled()


      it 'adds students to the course instances', (done) ->
        courseInstance = @view.courseInstances.first()
        courseInstance.set('members', [])
        @view.assignCourse(courseInstance.get('courseID'), @students.pluck('_id').slice(2, 4))
        @view.wait('begin-assign-course').then =>
          request = jasmine.Ajax.requests.mostRecent()
          expect(request.url).toBe("/db/course_instance/#{courseInstance.id}/members")
          expect(request.method).toBe('POST')
          done()
