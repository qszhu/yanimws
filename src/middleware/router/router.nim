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

proc add*(self: Router, `method`: HttpMethod, pattern: string, handlers: varargs[YaHandler]) =
  if `method` notin self.routes:
    self.routes[`method`] = newTrie()
  self.routes[`method`].add pattern, handlers

proc match(self: Router, `method`: HttpMethod, path: string): MatchResult =
  self.routes[`method`].match path

proc routes*(self: Router): YaHandler =
  let notFound: YaHandler = proc (c: YaContext) {.async, gcsafe.} =
    c.response.status = Http404

  return proc (c: YaContext) {.async, gcsafe.} =
    let m = self.match(c.request.`method`, c.request.path)
    if m.data.len == 0:
      c.use notFound
    else:
      c.use m.data
    c.request.params = m.params

    await c.next()
