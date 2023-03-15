import std/[
  asyncdispatch,
  asynchttpserver,
  sequtils,
  tables,
  uri,
]



type
  YaRequest* = ref object
    rawReq: Request
    params*: Table[string, string]
    queries*: Table[string, string]

proc newYaRequest*(req: Request): YaRequest =
  result.new
  result.rawReq = req
  result.queries = decodeQuery(req.url.query).toSeq.toTable

proc remoteAddr*(self: YaRequest): string {.inline.} =
  self.rawReq.hostname

proc `method`*(self: YaRequest): HttpMethod {.inline.} =
  self.rawReq.reqMethod

proc path*(self: YaRequest): string {.inline.} =
  self.rawReq.url.path

proc headers*(self: YaRequest): HttpHeaders {.inline.} =
  self.rawReq.headers

proc body*(self: YaRequest): string {.inline.} =
  self.rawReq.body

proc respond*(self: YaRequest, code: HttpCode, body: string, headers: HttpHeaders): Future[void] {.inline.} =
  self.rawReq.respond(code, body, headers)
