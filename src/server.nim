import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  logging,
  tables,
]
import system/ansi_c

import request, response
export request, response

type
  YaHandler* = proc (c: YaContext) {.async, gcsafe.}

  YaContext* = ref object
    request*: YaRequest
    response*: YaResponse
    server*: YaServer
    handlers*: seq[YaHandler]
    idx: int

  YaServer* = ref object
    middlewares: seq[YaHandler]
    config: Table[string, string]

proc newYaContext*(req: Request, server: YaServer): YaContext =
  result.new
  result.request = newYaRequest(req)
  result.response = newYaResponse()
  result.server = server
  result.idx = -1

proc next*(self: YaContext) {.async} =
  self.idx.inc
  if self.idx < self.handlers.len:
    let handler = self.handlers[self.idx]
    await handler(self)

proc use*(self: YaContext, handlers: varargs[YaHandler]) =
  for h in handlers:
    self.handlers.add h

proc text*(self: YaContext, text: string, code = Http200) =
  self.response.headers["Content-Type"] = "text/plain"
  self.response.status = code
  self.response.body = text

proc json*(self: YaContext, json: JsonNode, code = Http200) =
  self.response.headers["Content-Type"] = "application/json"
  self.response.status = code
  self.response.body = $json

proc send*(self: YaContext) {.async, inline.} =
  await self.request.respond(self.response.status, self.response.body, self.response.headers)



proc newYaServer*(): YaServer =
  result.new

proc set*(self: YaServer, key, value: string) {.inline.} =
  self.config[key] = value

proc get*(self: YaServer, key: string): string {.inline.} =
  self.config[key]

proc use*(self: YaServer, middlewares: varargs[YaHandler]) {.inline.} =
  for m in middlewares:
    self.middlewares.add m

proc run*(self: YaServer, port: Port, address = "") {.async.} =
  proc serve(req: Request) {.async, gcsafe.} =
    let ctx = newYaContext(req, self)
    ctx.handlers = self.middlewares
    await ctx.next()
    await ctx.send()

  let server = newAsyncHttpServer()
  for sig in [SIGINT, SIGTERM]:
    addSignal(sig, proc (fd: AsyncFD): bool =
      logging.notice "Server shutting down..."
      try:
        server.close()
      except:
        logging.error getCurrentExceptionMsg()
      finally:
        quit(QuitSuccess)
    )
  await server.serve(port, serve, address)
