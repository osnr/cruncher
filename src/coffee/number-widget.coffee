window.Cruncher = Cr = window.Cruncher || {}

class Cr.NumberWidget
    constructor: (@value, @pos, @onControlChange) ->
        @$numberWidget = $ '<div class="number-widget">' +
                              '<a id="connect"><i class="fa fa-circle-o"></i></a>' +
                              '<a id="computerize"><i class="fa fa-pencil-square"></i></a>' +
                            '</div>'

        @cid = Cr.getValueCid @value
        if @cid?
            @$numberWidget.find('#connect i')
                .addClass('fa-circle')
                .removeClass 'fa-circle-o'

        if typeof @value.num == 'function'
            # this is a free number
            @mark = (mark for mark in Cr.editor.findMarksAt \
                Cr.valueFrom @value when mark.className == 'free-number')[0]

    show: ->
        ($ '.number-widget').remove()
        
        Cr.editor.addWidget
            line: @pos.line
            ch: @value.start,
            @$numberWidget[0]

        @$number = $ '.CodeMirror-code .hovering-number'

        offset = @$number.offset()
        @$numberWidget #.width(($ this).width())
            .offset
                top: offset.top + @$number.height()
                left: offset.left - 3
            .mouseenter =>
                @$numberWidget
                    .stop(true)
                    .animate(opacity: 100)

            .on 'click', '#computerize', =>
                @setFreeNumber()

                @onControlChange @pos.line
                
            .on 'click', '#humanize', =>
                @unsetFreeNumber()

                @onControlChange @pos.line

            .on 'mousedown', '#connect', (event) =>
                fromCoords = Cr.editor.charCoords Cr.valueFrom @value
                toCoords = Cr.editor.charCoords Cr.valueTo @value

                @cid ?= Cr.newCid()

                Cr.startConnect @cid,
                    @value,
                    (toCoords.left + fromCoords.left) / 2,
                    (fromCoords.bottom + fromCoords.top) / 2

        @setFreeNumber ($ '#computerize') if @mark?

    setFreeNumber: ($target) =>
        if not @mark?
            @mark = Cr.markAsFree (Cr.valueFrom @value),
                (Cr.valueTo @value)

        ($ '#connect i.fa-circle-o')
            .removeClass('fa-circle-o')
            .addClass 'fa-arrow-circle-down'

        ($ '#computerize')
            .attr('id', 'humanize')
            .find('i')
                .removeClass('fa-pencil-square')
                .addClass 'fa-cogs'
        @$numberWidget.addClass 'free-number-widget'

    unsetFreeNumber: ($target) =>
        if @mark?
            @mark.clear()
            @mark = null

        ($ '#humanize')
            .attr('id', 'computerize')
            .find('i')
                .removeClass('fa-cogs')
                .addClass 'fa-pencil-square'
        @$numberWidget.removeClass 'free-number-widget'
