import std/[
  asyncdispatch,
  asynchttpserver,
  json,
  sequtils,
  strformat,
  tables,
  uri,
]

export json, tables



type
  YaRequestKV* = Table[string, string]

proc newYaRequestKV*(): YaRequestKV {.inline.} =
  initTable[string, string]()

proc newYaRequestKV*(jso: JsonNode): YaRequestKV =
  result = newYaRequestKV()
  for k, v in jso.pairs:
    if v.kind != JString:
      result[k] = $v
    else:
      result[k] = v.getStr

proc toJson*(self: YaRequestKV): JsonNode =
  result = %*{}
  for k, v in self.pairs:
    result[k] = %v

type
  YaRequestFile* = ref object
    filename*, path*: string

proc `$`*(self: YaRequestFile): string {.inline.} =
  &"filename: {self.filename}, path: {self.path}"

type
  YaRequest* = ref object
    rawReq: Request
    params*: YaRequestKV
    queries*: YaRequestKV
    body*: YaRequestKV
    json*: JsonNode
    files*: Table[string, YaRequestFile]

proc newYaRequest*(req: Request): YaRequest =
  result.new
  result.rawReq = req
  result.queries = decodeQuery(req.url.query).toSeq.toTable
  result.json = %*{}

proc remoteAddr*(self: YaRequest): string {.inline.} =
  self.rawReq.hostname

proc httpMethod*(self: YaRequest): HttpMethod {.inline.} =
  self.rawReq.reqMethod

proc path*(self: YaRequest): string {.inline.} =
  self.rawReq.url.path

proc headers*(self: YaRequest): HttpHeaders {.inline.} =
  self.rawReq.headers

proc rawBody*(self: YaRequest): string {.inline.} =
  self.rawReq.body

proc respond*(self: YaRequest, code: HttpCode, body: string, headers: HttpHeaders): Future[void] {.inline.} =
  self.rawReq.respond(code, body, headers)

proc raw*(self: YaRequest): Request {.inline.} =
  self.rawReq
