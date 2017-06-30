let id;
let terminal2class = {
  error: "error",
  EOF: "eof",
  NUMBER: "number",
  PLUS: "op",
  MINUS: "op",
  MUL: "op",
  DIV: "op",
  POW: "op",
  PAREN_OPEN: "paren",
  PAREN_CLOSE: "paren",
  HEADING: "heading",
  EQUALS: "equals"
};

let id2class = {};
for (let terminal in parser.symbols_) {
  id = parser.symbols_[terminal];
  id2class[id] = terminal2class[terminal];
}

CodeMirror.defineMode("cruncher", () => ({
  startState() {
    return parser.lexer;
  },

  token(stream, lexer) {
    lexer.setInput(stream.string.slice(stream.pos));
    id = lexer.next();
    for (
      let i = 0, end = lexer.yytext.length, asc = 0 <= end;
      asc ? i < end : i > end;
      asc ? i++ : i--
    ) {
      stream.next();
    }

    return id2class[id];
  }
}));
