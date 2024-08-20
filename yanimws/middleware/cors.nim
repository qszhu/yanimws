import ../server

proc Cors*(allowOrigin = "*", allowHeaders = "*", allowMethods = "*"): YaHandler =
  return proc(c: YaContext) {.async, gcsafe.} =
    if c.request.httpMethod == HttpOptions:
      c.text ""
    else:
      waitFor c.next()
    c.response.headers["Access-Control-Allow-Origin"] = allowOrigin
    c.response.headers["Access-Control-Allow-Headers"] = allowHeaders
    c.response.headers["Access-Control-Allow-Methods"] = allowMethods
