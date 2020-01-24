import strutils, tokenizer

type
  PageKind* = enum
    pkAsset, pkMarkdown, pkRst
  Page* = object
    case kind*: PageKind
    of pkMarkdown, pkRst:
      meta*, body*: string
    of pkAsset: discard

const supportedMarkups*: set[PageKind] = {pkMarkdown, pkRst}

when pkMarkdown in supportedMarkups:
  import markdown

when pkRst in supportedMarkups:
  import rstgen, rst, strtabs

proc metaToHead*(meta: string): string =
  type
    StateKind = enum
      inBlock, inTag, inAttrs, inAttrStart, inAttrEnd, inContent
    ElemOrString = ref object
      case isElem: bool
      of true:
        tag: string
        attrs: seq[(string, string)]
        content: seq[ElemOrString]
      else:
        str: string

  let tokens = meta.tokenize
  var state = inBlock
  var contentTagName = ""
  for t in tokens:
    case state
    of inBlock:
      case t.kind
      of pttWord:
        contentTagName = t.raw
        result.add('<')
        result.add(t.raw)
        state = inTag
      of pttNewline:
        result.add("\r\n")
      of pttString:
        result.add(t.raw)
      else: discard
    of inTag:
      case t.kind
      of pttColon:
        result.add('>')
        state = inContent
      of pttOpenParen:
        state = inAttrs
      of pttNewline:
        result.add('>')
        state = inBlock
      of pttWord:
        result.add('>')
        result.add(t.raw)
        state = inContent
      of pttString:
        result.add('>')
        result.add(t.raw)
        result.add("</")
        result.add(contentTagName)
        result.add('>')
        state = inBlock
      else:
        discard
    of inAttrs:
      case t.kind
      of pttCloseParen:
        result.add('>')
        state = inContent
      of pttWord:
        result.add(' ')
        result.add(t.raw)
        state = inAttrStart
      else:
        discard
    of inAttrStart:
      if t.kind == pttColon or (t.kind == pttSymbol and t.raw == "="):
        result.add('=')
        state = inAttrEnd
    of inAttrEnd:
      if t.kind in {pttWord, pttSymbol, pttString}:
        result.add('"')
        result.add(t.raw)
        result.add('"')
        state = inAttrs
    of inContent:
      case t.kind
      of pttWord:
        result.add(t.raw)
        result.add(' ')
      of pttNewline:
        result.add("</")
        result.add(contentTagName)
        result.add('>')
        state = inBlock
      of pttString:
        result.add(t.raw)
      else:
        discard

proc loadHypertext*(page: var Page, path: string) =
  if page.kind notin {pkMarkdown, pkRst}: return
  let file = open(path)
  var 
    line = ""
    recordMeta = false

  while file.readLine(line):
    if line.isNilOrWhitespace:
      continue
    elif line == "---":
      recordMeta = true
    else:
      page.body.add(line)
      page.body.add("\r\n")
    break
  if recordMeta:
    while file.readLine(line):
      if line == "---":
        break
      else:
        page.meta.add(line)
        page.meta.add("\r\n")
  while file.readLine(line):
    page.body.add(line)
    page.body.add("\r\n")
  file.close()

proc genRst(body: string): string =
  when pkRst in supportedMarkups:
    result = rstToHtml(body, {roSupportMarkdown, roSupportRawDirective}, newStringTable(modeStyleInsensitive))
  else:
    raise newException(ValueError, "rst not supported")


proc genMd(body: string): string =
  when pkMarkdown in supportedMarkups:
    result = markdown(body)
  else:
    raise newException(ValueError, "rst not supported")

proc toHtml*(page: Page, tmpl: string): string =
  result = tmpl.multiReplace({
    "$head": metaToHead(page.meta),
    "$body": case page.kind
             of pkMarkdown: genMd(page.body)
             of pkRst: genRst(page.body)
             else: ""
  })
