import std/[
  asyncdispatch,
  asynchttpserver,
  logging,
  nativesockets,
  os,
  strformat,
]

import ../server
import ../middleware/router/router
import ../middleware/[
  accesslog,
  recovery,
  timeout,
]


const BIND_ADDRESS = "0.0.0.0"
const BIND_PORT = 8080
const KEY_VERSION = "version"

let app = newYaServer()

app.set(KEY_VERSION, getEnv(KEY_VERSION))

app.use Logging()
app.use Recovery()
app.use Timeout(5000)

let r = newRouter()

r.add(HttpGet, "/", proc (c: YaContext) {.async, closure.} =
  for name, values in c.request.headers:
    c.response.headers[name] = values
  c.response.headers[KEY_VERSION] = c.server.get(KEY_VERSION)
)

r.add(HttpGet, "/healthz", proc (c: YaContext) {.async, closure.} =
  discard
)

r.add(HttpGet, "/error", proc (c: YaContext) {.async, closure.} =
  raise newException(ValueError, "boom!")
)

r.add(HttpGet, "/timeout", proc (c: YaContext) {.async, closure.} =
  await sleepAsync(10 * 1000)
  c.text("ok")
)

app.use r.routes

logging.notice &"Listening on {BIND_ADDRESS}:{BIND_PORT}..."
waitFor app.run(BIND_PORT.Port, BIND_ADDRESS)
