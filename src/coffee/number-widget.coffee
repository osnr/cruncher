window.Cruncher = Cr = window.Cruncher || {}

class Cr.NumberWidget
    constructor: (@value, @pos, @onLockChange) ->
        @$numberWidget = $ '<div class="number-widget"><a id="connect"><i class="fa fa-circle-o"></i></a><a id="unlock"><i class="fa fa-cogs"></i></a></div>'

        @cid = Cr.getValueCid @value
        if @cid?
            @$numberWidget.find('#connect i')
                .addClass('fa-circle')
                .removeClass 'fa-circle-o'

        if typeof value.num == 'function'
            # this is a free number
            @mark = (mark for mark in Cr.editor.findMarksAt \
                Cr.valueFrom value when mark.className == 'free-number')[0]

    show: ->
        ($ '.number-widget').remove()
        
        Cr.editor.addWidget
            line: @pos.line
            ch: @value.start,
            @$numberWidget[0]

        @$number = $ '.hovering-number'
        @$number.mouseleave @endHover

        offset = @$number.offset()
        @$numberWidget #.width(($ this).width())
            .offset
                top: offset.top + @$number.height() + 1
                left: offset.left - 3
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

                @cid ?= Cr.newCid()

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
            @mark = Cr.markAsFree (Cr.valueFrom @value),
                (Cr.valueTo @value)

        ($ '#connect i.fa-circle-o')
            .removeClass('fa-circle-o')
            .addClass 'fa-arrow-circle-down'

        ($ '#unlock')
            .attr('id', 'lock')
            .find('i')
                .removeClass('fa-cogs')
                .addClass 'fa-pencil-square'
        @$numberWidget.addClass 'free-number-widget'

    unsetFreeNumber: ($target) =>
        if @mark?
            @mark.clear()
            @mark = null

        ($ '#lock')
            .attr('id', 'unlock')
            .find('i')
                .removeClass('fa-pencil-square')
                .addClass 'fa-cogs'
        @$numberWidget.removeClass 'free-number-widget'
