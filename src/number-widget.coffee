window.Cruncher = Cr = window.Cruncher || {}

class Cr.NumberWidget
    constructor: (@value, @pos, @onLockChange) ->
        @$numberWidget = $ '<div class="number-widget"><a id="connect"><i class="icon-circle-blank"></i></a><a id="unlock"><i class="icon-lock"></i></a></div>'

        if typeof value.num == 'function'
            # this is a free number
            @mark = (mark for mark in Cr.editor.findMarksAt \
                Cr.valueFrom value when mark.className == 'free-number')[0]
            console.log @mark

        @cid = Cr.getCidFor @value
        if @cid?
            @$numberWidget.find('#connect i')
                .addClass('icon-circle')
                .removeClass 'icon-circle-blank'
        else
            @cid = Cr.newCid()
    show: ->
        ($ '.number-widget').remove()
        
        Cr.editor.addWidget
            line: @pos.line
            ch: @value.start,
            @$numberWidget[0]

        @$number = $ '.hovering-number'
        @$number.mouseleave @endHover

        @$numberWidget #.width(($ this).width())
            .offset (index, coords) ->
                top: coords.top
                left: coords.left
            .mouseenter =>
                @$number.off 'mouseleave'

                @$numberWidget
                    .stop(true)
                    .animate(opacity: 100)
                    .mouseleave @endHover
            
            .on 'click', '#unlock', =>
                @setFreeNumber()

                @onLockChange @pos.line
                
            .on 'click', '#lock', =>
                @unsetFreeNumber()

                @onLockChange @pos.line

            .on 'mousedown', '#connect', (event) =>
                fromCoords = Cr.editor.charCoords Cr.valueFrom @value
                toCoords = Cr.editor.charCoords Cr.valueTo @value

                Cr.startConnect @cid,
                    @value,
                    (toCoords.left + fromCoords.left) / 2,
                    (fromCoords.bottom + fromCoords.top) / 2

                @endHover()

        @setFreeNumber ($ '#unlock') if @mark?

    endHover: =>
        @$numberWidget.fadeOut 200, =>
            @$number.removeClass 'hovering-number'
            @$numberWidget.remove()

    setFreeNumber: ($target) =>
        if not @mark?
            @mark = Cr.editor.markText (Cr.valueFrom @value),
                (Cr.valueTo @value),
                { className: 'free-number' }

        ($ '#connect i.icon-circle-blank')
            .removeClass('icon-circle-blank')
            .addClass 'icon-circle-arrow-down'

        ($ '#unlock')
            .attr('id', 'lock')
            .find('i')
                .removeClass('icon-lock')
                .addClass 'icon-unlock'
        @$numberWidget.addClass 'free-number-widget'

    unsetFreeNumber: ($target) =>
        if @mark?
            @mark.clear()
            @mark = null

        ($ '#lock')
            .attr('id', 'unlock')
            .find('i')
                .removeClass('icon-unlock')
                .addClass 'icon-lock'
        @$numberWidget.removeClass 'free-number-widget'
