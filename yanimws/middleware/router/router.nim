import std/[
  asyncdispatch,
  asynchttpserver,
  tables,
]

import trie
import ../../server



type Router* = ref object
  routes: Table[HttpMethod, Trie]

proc newRouter*(): Router =
  result.new

proc add*(self: Router, httpMethod: HttpMethod, pattern: string, handlers: varargs[YaHandler]) =
  if httpMethod notin self.routes:
    self.routes[httpMethod] = newTrie()
  self.routes[httpMethod].add pattern, handlers

proc match(self: Router, httpMethod: HttpMethod, path: string): MatchResult =
  if httpMethod notin self.routes: nil
  else: self.routes[httpMethod].match path

proc routes*(self: Router): YaHandler =
  let notFound: YaHandler = proc (c: YaContext) {.async, gcsafe.} =
    c.response.status = Http404

  return proc (c: YaContext) {.async, gcsafe.} =
    let m = self.match(c.request.httpMethod, c.request.path)
    if m == nil or m.data.len == 0:
      c.use notFound
    else:
      c.use m.data
      c.request.params = m.params

    await c.next()
