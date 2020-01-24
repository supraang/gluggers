import pagegen, ftpupload

import os, strutils, times

const iso8601 = initTimeFormat("yyyy-MM-dd'T'HH:mm:sszzz")

type Params = tuple
  inDir, outDir, templFile: string
  files: seq[string]
  since: Time
  force, publish: bool

proc loadParams(params: var Params) =
  params.inDir = "files"
  params.outDir = "out"
  params.templFile = "template.html"
  if fileExists("gentime"):
    params.since = getLastModificationTime("gentime")
  else:
    params.force = true
  params.publish = false

  template next: untyped = paramStr((let m = i; inc i; m))
  
  var i = 1
  while i <= paramCount():
    case next
    of "--in", "-i":
      params.inDir = next
    of "--out", "-o":
      params.outDir = next
    of "--just", "-j":
      params.files = next.split(';')
    of "--template", "-t":
      params.templFile = next
    of "--force", "-f":
      params.force = true
    of "--since", "-s":
      params.since = parse(next, iso8601).toTime
    of "--publish", "-p":
      params.publish = true
  
  if getLastModificationTime(params.templFile) >= params.since:
    params.force = true

iterator walkFiles(params: Params): string =
  if params.files.len == 0:
    for path in walkDirRec(params.inDir):
      yield path
  else:
    for path in params.files:
      yield params.inDir / path

proc generate(params: Params) =
  let templ = readFile(params.templFile)
  
  var ftp: FtpInstance
  if params.publish:
    ftp.initClient()

  for path in params.walkFiles:
    if not params.force and getLastModificationTime(path) < params.since:
      continue
    var name = path
    name.removePrefix(params.inDir & DirSep)
    
    var page: Page
    
    if name.endsWith(".md"):
      page = Page(kind: pkMarkdown)
    elif name.endsWith(".rst"):
      page = Page(kind: pkRst)
    else:
      page = Page(kind: pkAsset)
    
    if page.kind in {pkMarkdown, pkRst}:
      echo "Parsing page: ", name
      page.loadHypertext(path)
      if name == "index.md":
        writeFile("indexMeta.txt", page.meta)
        writeFile("indexBody.txt", page.body)
      echo "Generating file: ", name
      let lenBack = if page.kind == pkMarkdown: 3 else: 4
      name.setLen(name.len - lenBack)
      name.add(".html")
      echo "Generated file: ", name
    
    let (nameHead, nameTail) = splitPath(name)
    let dir = params.outDir / nameHead
    let outFile = params.outDir / name

    createDir(dir)
    if page.kind in {pkMarkdown, pkRst}:
      writeFile(outFile, page.toHtml(templ))
    else:
      copyFile(path, outFile)
    
    if params.publish:
      ftp.uploadFile(nameHead, nameTail, outFile)

  if params.publish:
    ftp.close()
  
  writeFile("gentime", "")

proc main =
  var params: Params
  params.loadParams()
  generate(params)

when isMainModule:
  main()
