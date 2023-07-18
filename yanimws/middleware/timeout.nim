import std/[
  net,
  strformat,
]

import ../server



proc Timeout*(ms: int): YaHandler =
  return proc(c: YaContext) {.async, gcsafe.} =
    let finished = await c.next().withTimeout(ms)
    if not finished: raise newException(TimeoutError, &"Request timeout for {ms}ms")
