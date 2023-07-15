import std/[
  strformat,
]

import ../server
import ../middleware/router/router
import ../middleware/[
  accesslog,
  bodyparser,
  recovery,
]


const BIND_ADDR = "0.0.0.0"
const BIND_PORT = 8080


when isMainModule:
  when not defined(release):
    addHandler(newConsoleLogger(levelThreshold = lvlDebug))

  let app = newYaServer()

  app.use Logging()
  app.use Recovery()



  let r = newRouter()

  # http localhost:8080/json foo=bar
  let jsonHandler: YaHandler = proc (c: YaContext) {.async.} =
    logging.debug c.request.json

  # http --form localhost:8080/form foo=bar
  let formHandler: YaHandler = proc (c: YaContext) {.async.} =
    logging.debug c.request.body

  # http -f localhost:8080/file foo=bar fn@README.md
  let uploadHandler: YaHandler = proc (c: YaContext) {.async.} =
    logging.debug c.request.body
    logging.debug c.request.files

  r.add(HttpPost, "/json", BodyParser(), jsonHandler)
  r.add(HttpPost, "/form", BodyParser(), formHandler)
  r.add(HttpPost, "/file", BodyParser(), uploadHandler)

  app.use r.routes

  logging.notice &"Listening on {BIND_ADDR}:{BIND_PORT}..."
  waitFor app.run(BIND_PORT.Port, BIND_ADDR)
