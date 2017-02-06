window.Cruncher = Cr = window.Cruncher || {}

CodeMirror.TextMarker::toSerializable = ->
    return null unless @className? and
        ((@className.indexOf("connected-number")) is 0 or
          @className is "free-number" or
          @className is "locked-number")

    {from, to} = @.find()

    from: from
    to: to
    cid: @cid
    options:
        className: @className
        inclusiveLeft: @inclusiveLeft
        inclusiveRight: @inclusiveRight
        atomic: @atomic

$ ->
    # Initialize Firebase
    config =
        apiKey: "AIzaSyBbisLJOm0QPhkeMCpPXLtlW-_PZd2sHUY"
        authDomain: "cruncher-4719b.firebaseapp.com"
        databaseURL: "https://cruncher-4719b.firebaseio.com"
        storageBucket: "cruncher-4719b.appspot.com"
        messagingSenderId: "715362151432"
    firebase.initializeApp config
    db = firebase.database()

    serializeDoc = ->
        JSON.stringify
            version: Cr.VERSION
            title: Cr.editor.doc.title
            text: Cr.editor.getValue()
            marks: (m for m in (mark.toSerializable() \
                for mark in Cr.editor.getAllMarks()) \
                    when m?)
            , null, 2

    deserializeDoc = (data, key, mode = 'edit', settings) ->
        console.log data
        data = JSON.parse data
        doc = CodeMirror.Doc data.text, 'cruncher'
        key ?= db.ref('docs').push().key
        doc.key = key
        doc.title = data.title
        doc.settings = settings
        Cr.editor.swapDoc doc

        for mark in data.marks
            newMark = Cr.editor.markText mark.from, mark.to, mark.options
            newMark.cid = mark.cid

        Cr.swappedDoc mode

    ($ '.new-doc').click ->
        do Cr.newDoc

    ($ '.import-doc').click ->
        ($ '#file-chooser').click()

    ($ '#file-chooser').change (event) ->
        file = event.target.files[0]
        reader = new FileReader()
        reader.onload = ->
            try
                deserializeDoc reader.result
            catch e
                alert 'Error loading file.'

        reader.readAsText file
        this.value = null

    ($ '.export-doc').click ->
        blob = new Blob([serializeDoc()],
            type: 'text/plain; charset=utf-8'
        )
        title = Cr.editor.doc.title
        title = (if title.match(/\.[Cc][Rr]$/) then title else title + '.cr')
        saveAs blob, title

    ($ '.save-doc').click ->
        Cr.saveDoc(Cr.editor.doc)

    ($ '.publish-doc').click ->
        if not Cr.editor.doc.uid?
            alert 'You need to save to a link before publishing.'
            return

        ($ '#publish').modal('show')

    ($ '.do-publish').click ->
        settings =
            editable: ($ '.publish-editable').prop('checked')
            scrubbable: ($ '.publish-scrubbable').prop('checked')
            gutter: ($ '.publish-gutter').prop('checked')
            hints: ($ '.publish-hints').prop('checked')
        console.log settings

        Cr.publishDoc Cr.editor.doc.uid, settings,
            success: (publishId) ->
                baseUrl = window.location.href.match(/(^[^\?]*)/)[1]
                viewUrl = baseUrl + '?/view/' + publishId
                embedUrl = baseUrl + '?/embed/' + publishId

                ($ '.view-url').val viewUrl
                ($ '.embed-code').val '<iframe src="' + embedUrl + '"></iframe>'
                ($ '.embed-preview').attr 'src', embedUrl

    Cr.newDoc = ->
        doc = CodeMirror.Doc('', 'cruncher')
        doc.key = db.ref('docs').push().key
        Cr.editor.swapDoc doc
        Cr.swappedDoc 'Untitled'

    Cr.loadView = (viewKey) ->
        db.ref("docs/#{viewKey}").once('value')
            .then((response) ->
                val = response.val()
                deserializeDoc val.data, viewKey, 'view', val.settings
            ).catch((error) ->
                alert 'Failed to load published document: ' + error
                Cr.newDoc()
            )

    Cr.loadEmbed = (viewid) -> # FIXME merge with loadView
        Parse.Cloud.run "getPublish", { publishId: viewid },
            success: (response) ->
                deserializeDoc response.data, viewid, 'embed', response.settings

            error: (response, error) ->
                alert 'Failed to load published document: ' + error
                Cr.newDoc()

    Cr.loadExample = (tid) ->
        ($ '#loading').fadeIn()

        ($.get 'https://cruncher-examples.s3.amazonaws.com/' + tid, (data) ->
            ($ '#loading').fadeOut()
            deserializeDoc data, null
        ).fail ->
            ($ '#loading').fadeOut()
            Cr.newDoc()

    Cr.loadDoc = (key) ->
        ($ '#loading').fadeIn()

        if key.substring(0, 'examples/'.length) == 'examples/'
            Cr.loadExample (key.substring 'examples/'.length)
            return

        db.ref("docs/#{key}").once('value')
            .then((response) ->
                ($ '#loading').fadeOut()
                val = response.val()
                deserializeDoc val, key
            ).catch((error) ->
                console.log error
                ($ '#loading').fadeOut()
                Cr.newDoc()
            )

    Cr.saveDoc = (doc) ->
        db.ref("docs/" + doc.key).set(serializeDoc(doc))
        Cr.markClean()

    Cr.publishDoc = (callbacks) ->
        publishedKey = db.ref('publishedDocs').push().key
        db.ref("publishedDocSaveKeys/" + publishedKey).set()

        db.ref("publishedDocs/" + publishedKey)
        Parse.Cloud.run "publish", { saveId: uid, data: serializeDoc(), settings: settings },
            success: (response) ->
                callbacks.success response.publishId
                console.log 'published', response

            error: (response, error) ->
                callbacks.error response, error
                console.log 'error', response, error

