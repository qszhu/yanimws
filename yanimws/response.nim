import std/[
  asynchttpserver,
]



type
  YaResponse* = ref object
    status*: HttpCode
    headers*: HttpHeaders
    body*: string

proc newYaResponse*(): YaResponse =
  result.new
  result.status = Http200
  result.headers = newHttpHeaders()
