import std/[
  asyncdispatch,
  asynchttpserver,
  deques,
  logging,
  nativesockets,
  strformat,
  tables,
  times,
]

import ../server
import ../middleware/router/router
import ../middleware/[
  accesslog,
  recovery,
]



proc RateLimiter*(spanSec, limit: int): YaHandler =
  var reqRec: Table[string, Deque[float]]
  return proc(c: YaContext) {.async, gcsafe.} =
    let remoteAddr = c.request.remoteAddr
    let ts = getTime().toUnixFloat
    var accesses = reqRec.getOrDefault(remoteAddr, initDeque[float]())
    accesses.addLast ts
    while accesses[0] < ts - spanSec.float:
      discard accesses.popFirst
    reqRec[remoteAddr] = accesses
    if accesses.len > limit:
      raise newException(CatchableError, "Rate limit exceeded.")
    waitFor c.next()



const BIND_ADDRESS = "0.0.0.0"
const BIND_PORT = 8080

let app = newYaServer()

app.use Logging()
app.use Recovery()

let r = newRouter()

let ok = cast[YaHandler](proc (c: YaContext) {.async, closure.} =
  c.json %*{ "result": "ok" }
)

r.add(HttpGet, "/", RateLimiter(1, 1), ok)

app.use r.routes

logging.notice &"Listening on {BIND_ADDRESS}:{BIND_PORT}..."
waitFor app.run(BIND_PORT.Port, BIND_ADDRESS)
