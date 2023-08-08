import std/[
  asyncdispatch,
  json,
  httpclient,
  sequtils,
  uri,
]

import ../../server
import ../../middleware/auth/baseAuth

export baseAuth



type
  AuthClient* = ref object of RootObj
    host*: Uri
    auth*: BaseAuth

proc newAuthClient*(host: string, auth: BaseAuth): AuthClient =
  result.new
  result.host = host.parseUri
  result.auth = auth

method request*(self: AuthClient, path: string,
  data: JsonNode = "{}".parseJson, httpMethod = HttpGet
): Future[JsonNode] {.async, base.} =
  var client = newAsyncHttpClient()

  let headers = newHttpHeaders({ "Content-Type": "application/json" })

  var url = self.host / path
  var body = ""
  let params = self.auth.signParams(data)

  if httpMethod in [HttpGet, HttpDelete]:
    url = url ? newYaRequestKV(params).pairs.toSeq
  elif httpMethod in [HttpPost, HttpPut]:
    body = $params
  else:
    raise newException(ValueError, "unsupported http method " & $httpMethod)

  let res = await client.request(
    url = url,
    httpMethod = httpMethod,
    body = body,
    headers = headers
  )
  body = await res.body
  client.close
  return body.parseJson



when isMainModule:
  import ./auth

  let client = newAuthClient("http://localhost:5000", newAuth("test_key", "test_secret"))
  # let resp = waitFor client.request("/ping/auth", %*{ "foo": "bar" })
  let resp = waitFor client.request("/ping/auth", %*{
    "foo": "bar",
    "egg": 42,
    "baz": [1, 2, 3],
    "spam": %*{
      "baz": [4, 5, 6],
    }
  }, HttpPost)
  echo resp
