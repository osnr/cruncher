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

    serializeDoc = ->
        JSON.stringify
            version: Cr.VERSION
            title: Cr.editor.doc.title
            text: Cr.editor.getValue()
            marks: (m for m in (mark.toSerializable() \
                for mark in Cr.editor.getAllMarks()) \
                    when m?)
            , null, 2

    deserializeDoc = (data, uid) ->
        data = JSON.parse data
        uid = uid ? Cr.editor.doc.uid # reuse old UID if necessary
        Cr.editor.swapDoc (CodeMirror.Doc data.text, 'cruncher')

        for mark in data.marks
            newMark = Cr.editor.markText mark.from, mark.to, mark.options
            newMark.cid = mark.cid

        Cr.swappedDoc uid, data.title

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

    Cr.loadDoc = (uid) ->
        ($ '#loading').fadeIn()

        query = new Parse.Query(Doc)
        query.get uid,
            success: (doc) ->
                ($ '#loading').fadeOut()
                deserializeDoc doc.get('data'), uid

            error: (doc, error) ->
                ($ '#loading').fadeOut()
                doc = new Doc()
                Cr.newDoc uid

        ($.get 'https://cruncher-files.s3.amazonaws.com/' + uid, (data) ->
            ($ '#loading').fadeOut()
            deserializeDoc data, uid
        ).fail ->
            ($ '#loading').fadeOut()
            Cr.newDoc uid

    Cr.saveDoc = (uid) ->
        doc = new Doc()
        doc.id = uid
        doc.set('data', serializeDoc())

        do Cr.editor.doc.markClean
        doc.save null,
            success: (doc) -> console.log 'success', doc
            error: (doc, error) -> console.log 'error', doc, error

    Cr.autosave = ->
        if not Cr.editor.doc.isClean()
            Cr.saveDoc Cr.editor.doc.uid
