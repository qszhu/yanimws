import ../../server
import ./baseAuth



proc AuthMiddleware*(auth: BaseAuth): YaHandler =
  let handler = cast[YaHandler](proc(c: YaContext) {.async, closure.} =
    if not auth.checkSign(c):
      c.text "Unauthorized", Http401
    else:
      waitFor c.next()
  )
  return handler
