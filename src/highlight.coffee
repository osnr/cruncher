do ->
    window.Cruncher ||= {}

    terminal2class =
        error: 'error'
        EOF: 'eof'
        NUMBER: 'number'
        UNIT: 'unit'
        PLUS: 'op'
        MINUS: 'op'
        MUL: 'op'
        DIV: 'op'
        POW: 'op'
        PCT_OFF: 'op'
        PAREN_OPEN: 'paren'
        PAREN_CLOSE: 'paren'
        HEADING: 'heading'
        EQUALS: 'equals'

    window.id2class = {}
    for terminal, id of parser.symbols_
        id2class[id] = terminal2class[terminal]

    Cruncher.tokenize = (text) ->
        console.log text
        tokens = []
        # scan range
        lexer = parser.lexer

        i = 0
        while i < text.length
            lexer.setInput text[i ...]
            id = lexer.next()
            i += lexer.yytext.length

            tokens.push
                text: lexer.yytext
                id: id2class[id]

        tokens

