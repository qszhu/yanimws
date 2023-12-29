import std/[
  strutils,
]

import ../../server
import ../../middleware/router/router
import ../../middleware/bodyparser



proc addRoutes*(r: Router, auth: YaHandler) =
  let bodyParser = BodyParser()

  let ping = cast[YaHandler](proc (c: YaContext) {.async, closure.} =
    c.text("pong")
  )

  let pingAuthQuery = cast[YaHandler](proc (c: YaContext) {.async, closure.} =
    logging.debug c.request.queries

    c.json %*{"result": "ok"}
  )

  let pingAuthBody = cast[YaHandler](proc (c: YaContext) {.async, closure.} =
    logging.debug c.request.json

    c.json %*{"result": "ok"}
  )

  r.add(HttpGet, "/ping", ping)
  r.add(HttpGet, "/ping/auth", auth, pingAuthQuery)
  r.add(HttpDelete, "/ping/auth", auth, pingAuthQuery)
  r.add(HttpPost, "/ping/auth", bodyParser, auth, pingAuthBody)
  r.add(HttpPut, "/ping/auth", bodyParser, auth, pingAuthBody)

  let corsHandler = cast[YaHandler](proc (c: YaContext) {.async, closure.} =
    c.response.headers["Access-Control-Allow-Origin"] = "*"
    c.response.headers["Access-Control-Allow-Headers"] = "*"
    c.text ""
  )
  r.add(HttpOptions, "ping", corsHandler)
