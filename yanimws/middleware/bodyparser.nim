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
const CONTENT_TYPE_FORMDATA = "multipart/form-data"

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

proc BodyParser*(): YaHandler =
  return proc(c: YaContext) {.async, gcsafe.} =
    var contentType = ""
    try:
      contentType = c.request.headers[CONTENT_TYPE, 0]
    except:
      discard

    case contentType.toLowerAscii:
    of CONTENT_TYPE_JSON:
      c.request.json = c.request.rawBody.parseJson
    of CONTENT_TYPE_FORMDATA:
      # TODO
      discard
    else:
      c.request.body = parseFormUrlEncoded(c.request.rawBody)

    waitFor c.next()
