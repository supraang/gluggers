import streams

type
  Result* = object
    head*, body*: string
  
  ElemTerminatorKind = enum
    terIndentBack, terNewline, terQuote, terTripleQuote, 
    terHtml, 
  
  ElementToken = ref object
    de
  
  ParserState = enum
    psBody, psHead

proc parse*(s: Stream): Result =
  var
    state: ParserState
    elem: ElementToken
  var ch: char
  template next: char = (s.read(ch); ch)
  while not s.atEnd:
    case state
    of psBody:
      case next
      of '-':
        
