import std/[
  mimetypes,
  os,
  strutils,
]

import ../server



proc getTargetFileParts(root, path: string): seq[string] =
  result = @[root]
  for p in path.split("/"):
    if p.len == 0 or p == ".": continue
    if p == "..":
      if result.len - 1 <= 0: return
      discard result.pop
    else:
      result.add p
  # expects a file with extension
  if "." notin result[^1]:
    result.add "index.html"

proc Static*(root: string, prefix = ""): YaHandler =
  let m = newMimetypes()
  return proc(c: YaContext) {.async, gcsafe.} =
    var path = c.request.path
    if prefix.len > 0 and path.startsWith(prefix):
      path = path[prefix.len ..< path.len]
    let parts = getTargetFileParts(root, path)
    let ext = parts[^1].split(".")[^1]
    let mime = m.getMimetype(ext)
    let target = parts.join("/")
    logging.debug "serving ", target
    if fileExists(target):
      c.text(target.readFile, contentType=mime)
    else:
      await c.next()
