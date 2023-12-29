import ../server

proc Cors*(allowOrigin = "*", allowHeaders = "*"): YaHandler =
  return proc(c: YaContext) {.async, gcsafe.} =
    waitFor c.next()
    c.response.headers["Access-Control-Allow-Origin"] = allowOrigin
    c.response.headers["Access-Control-Allow-Headers"] = allowHeaders
