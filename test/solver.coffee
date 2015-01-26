util = require('util')

casper.test.begin 'Two plus three', 4, (test) ->
    casper.start 'http://localhost:9888/', ->
        @.sendKeys '#code', '2 '
        @.sendKeys '#code', '+', modifiers: 'shift'
        @.sendKeys '#code', ' 3'

    casper.wait 500, ->
        test.assertEquals (util.getLine 0), '2 + 3 = 5',
            'line content is 2 + 3 = 5'

        cursor = util.getCursor()
        test.assertEquals cursor.line, 0,
            'cursor is at line 0'
        test.assertEquals cursor.ch, 5,
            'cursor is at ch 5'

        @.sendKeys '#code', '1'

    casper.wait 500, ->
        test.assertEquals (util.getLine 0), '2 + 31 = 33',
            'line content is 2 + 31 = 33'

    casper.run ->
        test.done()
