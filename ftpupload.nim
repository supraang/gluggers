import asyncftpclient, asyncdispatch, strutils, os, terminal, asyncnet

const
  host = "ftpupload.net"
  root = "/metagod.gq/htdocs"

type
  Directory* = ref object
    name*: string
    children*: seq[Directory]

  FtpInstance* = object
    ftp*: AsyncFtpClient
    rootDir*: Directory

proc newDirectory*(name: string): Directory =
  new(result)
  shallow(result.children)
  result.name = name

proc fillDirs*(ftp: AsyncFtpClient, d: Directory, fullDir: string) =
  for dr in waitFor(ftp.listDirs(fullDir)):
    d.children.add(newDirectory(dr))

proc initClient*(instance: var FtpInstance) =
  instance.rootDir = newDirectory(root)
  instance.ftp = newAsyncFtpClient(host,
    user = getEnv("GLUGGERS_FTP_USER"),
    pass = getEnv("GLUGGERS_FTP_PASS"))
  waitFor instance.ftp.connect()
  instance.ftp.fillDirs(instance.rootDir, root)

proc uploadFile*(instance: FtpInstance, pathHead, pathTail, outPath: string) =
  var
    lastDir = instance.rootDir
    partDir = ""
    fullDir = root
  for p in split(pathHead, DirSep):
    partDir.add('/')
    partDir.add(p)
    fullDir.add('/')
    fullDir.add(p)
    block innerLoop:
      for d in lastDir.children:
        if d.name == p:
          instance.ftp.fillDirs(d, fullDir)
          lastDir = d
          break innerLoop
      waitFor instance.ftp.createDir(fullDir)
      let d = newDirectory(p)
      lastDir.children.add(d)
      lastDir = d
  echo "Uploading: ", pathHead, '/', pathTail

  waitFor instance.ftp.store(outPath, fullDir & '/' & pathTail,
    proc (total, progress: BiggestInt, speed: float) {.async.} =
      eraseLine()
      echo "Uploading: ", formatSize(progress), "/", formatSize(total), ", speed: ", speed)

proc close*(instance: FtpInstance) {.inline.} =
  instance.ftp.csock.close()
