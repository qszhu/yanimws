import std/[
  asyncdispatch,
  logging,
  strformat,
  times,
]

import ../server



proc setLogging() =
  var logger = newConsoleLogger(
    fmtStr = "[$datetime] - ",
    levelThreshold = lvlInfo,
  )
  addHandler(logger)

setLogging()

proc Logging*(): YaHandler =
  return proc(c: YaContext) {.async, gcsafe.} =
    logging.info &"{c.request.remoteAddr} -> {c.request.`method`} {c.request.path}"
    let t = cpuTime()
    waitFor c.next()
    let elapsed = cpuTime() - t
    logging.info &"{c.request.remoteAddr} <- {c.request.`method`} {c.request.path} {c.response.status.int} ({elapsed * 1000:.3f}ms)"
