import std/[
  asyncdispatch,
  asynchttpserver,
  logging,
  strutils,
]

import ../server



proc Recovery*(): YaHandler =
  return proc(c: YaContext) {.async, gcsafe.} =
    try:
      waitFor c.next()
    except:
      logging.error getCurrentException().getStackTrace
      logging.error getCurrentExceptionMsg()
      c.text(getCurrentExceptionMsg(), Http500)
