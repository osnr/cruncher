window.Cruncher = Cr = window.Cruncher || {}

CodeMirror.TextMarker::toSerializable = ->
    return null unless @className? and
        ((@className.indexOf("connected-number")) is 0 or @className is "free-number")

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
    Parse.initialize("m1vgRwDNCkaGLUgVcHu0awPVj6rMCN709dGSZpJu",
        "mlx5yORpt3sIK3mqaX3eW4lhtimn9KQZDJkxJJNK")
    Doc = Parse.Object.extend("Doc")
    PublishDoc = Parse.Object.extend("PublishDoc")

    serializeDoc = ->
        JSON.stringify
            version: Cr.VERSION
            title: Cr.editor.doc.title
            text: Cr.editor.getValue()
            marks: (m for m in (mark.toSerializable() \
                for mark in Cr.editor.getAllMarks()) \
                    when m?)
            , null, 2

    deserializeDoc = (data, uid, mode = 'edit') ->
        data = JSON.parse data
        uid = uid ? Cr.editor.doc.uid # reuse old UID if necessary
        Cr.editor.swapDoc (CodeMirror.Doc data.text, 'cruncher')

        for mark in data.marks
            newMark = Cr.editor.markText mark.from, mark.to, mark.options
            newMark.cid = mark.cid

        Cr.swappedDoc uid, data.title, mode

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
        Cr.saveDoc Cr.editor.doc.uid

    ($ '.publish-doc').click ->
        if not Cr.editor.doc.uid?
            alert 'You need to save to a link before publishing.'
            return

        ($ '#publish').modal('show')

    ($ '.do-publish').click ->
        Cr.publishDoc Cr.editor.doc.uid,
            success: (publishId) ->
                baseUrl = window.location.href.match(/(^[^\?]*)/)[1]
                viewUrl = baseUrl + '?/view/' + publishId
                embedUrl = baseUrl + '?/embed/' + publishId

                ($ '.view-url').val viewUrl
                ($ '.embed-code').val '<iframe src="' + embedUrl + '"></iframe>'
                ($ '.embed-preview').attr 'src', embedUrl

    Cr.loadView = (viewid) ->
        Parse.Cloud.run "getPublish", { publishId: viewid },
            success: (response) ->
                deserializeDoc response.data, viewid, 'view'

            error: (response, error) ->
                alert 'Failed to load published document: ' + error 
                Cr.newDoc()

    Cr.loadEmbed = (viewid) -> # FIXME merge with loadView
        Parse.Cloud.run "getPublish", { publishId: viewid },
            success: (response) ->
                deserializeDoc response.data, viewid, 'embed'

            error: (response, error) ->
                alert 'Failed to load published document: ' + error
                Cr.newDoc()

    Cr.loadDoc = (uid) ->
        ($ '#loading').fadeIn()

        query = new Parse.Query(Doc)
        query.get uid,
            success: (doc) ->
                ($ '#loading').fadeOut()
                deserializeDoc doc.get('data'), uid

            error: (doc, error) ->
                ($ '#loading').fadeOut()
                Cr.newDoc()

    Cr.saveDoc = (uid) ->
        doc = new Doc()
        doc.id = uid
        doc.set('data', serializeDoc())

        doc.save null,
            success: (doc) ->
                Cr.editor.doc.uid = doc.id
                history.replaceState {}, "", "?/" + doc.id
                console.log 'success', doc

                Cr.markClean()

            error: (doc, error) -> console.log 'error', doc, error

    Cr.publishDoc = (uid, callbacks) ->
        Parse.Cloud.run "publish", { saveId: uid, data: serializeDoc() },
            success: (response) ->
                callbacks.success response.publishId
                console.log 'published', response

            error: (response, error) ->
                callbacks.error response, error
                console.log 'error', response, error
