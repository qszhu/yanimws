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
  if "." notin result[^1]:
    result.add "index.html"

proc Static*(root: string): YaHandler =
  let m = newMimetypes()
  return proc(c: YaContext) {.async, gcsafe.} =
    let parts = getTargetFileParts(root, c.request.path)
    let mime = m.getMimetype(parts[^1].split(".")[^1])
    let target = parts.join("/")
    logging.debug "serving ", target
    if fileExists(target):
      c.text(target.readFile, contentType=mime)
    else:
      await c.next()
