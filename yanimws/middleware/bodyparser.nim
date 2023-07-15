import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  parseutils,
  strutils,
  uri,
]

import ../server

export uri



const CONTENT_TYPE = "content-type"
const CONTENT_TYPE_JSON = "application/json"
const CONTENT_TYPE_FORM = "application/x-www-form-urlencoded"
const CONTENT_TYPE_MULTIPART = "multipart/form-data"

proc parseFormUrlEncoded*(body: string): YaRequestKV =
  result = newYaRequestKV()
  var key, val = ""
  var consumed = 0
  while consumed < body.len:
    consumed += body.parseUntil(key, "=", consumed)
    consumed += 1
    consumed += body.parseUntil(val, "&", consumed)
    consumed += 1
    result[decodeUrl(key)] = decodeUrl(val)

proc parseMultiPart(r: YaRequest, boundary: string) =
  let endBoundary = "--" & boundary & "--"
  let boundary = "--" & boundary

  var line = ""
  var consumed = 0
  proc readLine() =
    consumed += r.rawBody.parseUntil(line, "\r\n", consumed)
    consumed += 2

  proc parseKeys(): Table[string, string] =
    result = initTable[string, string]()
    for part in line.strip.split(";"):
      let parts = part.strip.split("=")
      if parts.len != 2: continue
      let k = parts[0]
      let v = parts[1][1 ..< ^1]
      result[k] = v

  var keys = initTable[string, string]()
  var sofar = newSeq[string]()
  while consumed < r.rawBody.len:
    readLine()
    if line.startsWith(boundary):
      if sofar.len > 0:
        let content = sofar.join("\n")
        sofar = newSeq[string]()

        if "filename" in keys:
          r.files[keys["name"]] = YaRequestFile(filename: keys["filename"], content: content)
        else:
          r.body[keys["name"]] = content

        keys = initTable[string, string]()

      if line != endBoundary:
        readLine()
        keys = parseKeys()
        readLine()
    else:
      sofar.add line

proc BodyParser*(): YaHandler =
  return proc(c: YaContext) {.async, gcsafe.} =
    var contentType = ""
    try:
      contentType = c.request.headers[CONTENT_TYPE, 0]
    except:
      discard
    contentType = contentType.toLowerAscii

    if contentType == CONTENT_TYPE_JSON:
      c.request.json = c.request.rawBody.parseJson
    elif contentType.startsWith(CONTENT_TYPE_FORM):
      c.request.body = parseFormUrlEncoded(c.request.rawBody)
    elif contentType.startsWith(CONTENT_TYPE_MULTIPART):
      let boundary = contentType.split("boundary=")[1]
      parseMultiPart(c.request, boundary)

    waitFor c.next()
