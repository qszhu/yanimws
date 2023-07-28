import std/[
  algorithm,
  sequtils,
  strutils,
  strformat,
  times,
]

import nimcrypto

import ../../server
import ../../middleware/auth/baseAuth



const KEY_KEY = "key"
const KEY_TS = "ts"
const KEY_SIG = "sig"
const SIG_EXPIRE = 5 * 60

proc currentTimestamp(): int64 {.inline.}

type
  Auth* = ref object of BaseAuth

proc newAuth*(key, secret: string): Auth =
  result.new
  result.key = key
  result.secret = secret

proc getParams(self: Auth, c: YaContext): JsonNode
proc genSign(self: Auth, params: JsonNode): string

method genSign*(self: Auth, c: YaContext): string =
  self.genSign(self.getParams(c))

method checkSign*(self: Auth, c: YaContext): bool =
  var params = self.getParams(c)
  logging.debug params

  for k in [KEY_KEY, KEY_TS, KEY_SIG]:
    if k notin params:
      logging.debug "missing auth param: ", k
      return false

  let key = params[KEY_KEY].getStr
  if key != self.key:
    logging.debug "auth key mismatch"
    return false

  let ts = params[KEY_TS].getStr.parseBiggestInt
  if currentTimestamp() - ts >= SIG_EXPIRE:
    logging.debug "sig expired"
    return false

  let sign = params[KEY_SIG].getStr
  params.delete KEY_SIG
  if self.genSign(params) != sign:
    logging.debug "sig mismatch"
    return false

  true

method signParams*(self: Auth, params: JsonNode): JsonNode =
  result = params
  result[KEY_KEY] = %self.key
  result[KEY_TS] = %($currentTimestamp())
  result[KEY_SIG] = %self.genSign(result)

proc getParams(self: Auth, c: YaContext): JsonNode =
  logging.debug c.request.queries
  logging.debug c.request.rawBody
  if c.request.rawBody.len == 0:
    c.request.queries.toJson
  elif c.request.json != nil:
    c.request.json
  else:
    c.request.body.toJson

proc genSign(self: Auth, params: JsonNode): string =
  let
    keys = params.keys.toSeq.sorted
    paramStr = keys.mapIt(&"{it}={params[it]}").join("&")
    signStr = paramStr & self.secret
  result = ($sha256.digest(signStr)).toLowerAscii



proc currentTimestamp(): int64 {.inline.} =
  now().toTime.toUnix
