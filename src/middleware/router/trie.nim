import std/[
  strutils,
  sequtils,
  tables,
]

import ../../server


const WILDCARD = "*"

proc isWildcard(segment: string): bool {.inline.} =
  segment.startsWith ":"


type MatchResult* = ref object
  data*: seq[YaHandler]
  params*: Table[string, string]

type TrieNode {.acyclic.} = ref object
  paramName: string
  children: Table[string, TrieNode]
  data: seq[YaHandler]

proc newTrieNode(): TrieNode =
  result.new

type Trie* = ref object
  root: TrieNode

proc newTrie*(): Trie =
  result.new
  result.root = newTrieNode()

proc add(self: Trie, parent: TrieNode, segments: var seq[string], i: int, data: seq[YaHandler]) =
  if i == segments.len:
    parent.data = data
    return

  var
    seg = segments[i]
    paramName = ""

  if seg.isWildcard:
    paramName = seg[1 .. ^1]
    seg = WILDCARD

  if seg notin parent.children:
    parent.children[seg] = newTrieNode()

  let child = parent.children[seg]
  child.paramName = paramName
  self.add(child, segments, i + 1, data)

proc add*(self: Trie, path: string, data: varargs[YaHandler]) =
  var segments = path.split("/")
  self.add(self.root, segments, 0, data.toSeq)

proc match(self: Trie, parent: TrieNode, segments: var seq[string], i: int, result: var MatchResult) =
  if i == segments.len:
    result.data = parent.data
    return

  let seg = segments[i]

  var child: TrieNode
  if seg notin parent.children:
    if WILDCARD notin parent.children: return
    child = parent.children[WILDCARD]
    result.params[child.paramName] = seg
  else:
    child = parent.children[seg]

  self.match(child, segments, i + 1, result)

proc match*(self: Trie, path: string): MatchResult =
  result.new
  var segments = path.split("/")
  self.match(self.root, segments, 0, result)


discard """
when isMainModule:
  block:
    let trie = newTrie()
    trie.add "/foo", "foo"
    trie.add "/bar", "bar"
    trie.add "/foo/bar", "foo/bar"

    var m = trie.match "/foo" 
    doAssert m.data[0] == "foo"

    m = trie.match "/bar"
    doAssert m.data[0] == "bar"

    m = trie.match "/foo/bar"
    doAssert m.data[0] == "foo/bar"

    m = trie.match "/bar/foo"
    doAssert m.data.len == 0

  block:
    let trie = newTrie()
    trie.add "/post/:id", "postId"
    trie.add "/post/:id/publish", "publish"
    trie.add "/post/:id/comment/:cid", "comment"

    var m = trie.match "/post/123"
    doAssert m.data[0] == "postId"
    doAssert m.params["id"] == "123"

    m = trie.match "/post/456/publish"
    doAssert m.data[0] == "publish"
    doAssert m.params["id"] == "456"

    m = trie.match "/post/789/comment/abc"
    doAssert m.data[0] == "comment"
    doAssert m.params["id"] == "789"
    doAssert m.params["cid"] == "abc"

  block:
    let trie = newTrie()
    trie.add "/post/:id", "/post/:id"
    trie.add "/:action/id", "/:action/id"

    var m = trie.match "/post/id"
    doAssert m.data[0] == "/post/:id"
    doAssert m.params["id"] == "id"

    m = trie.match "/action/id"
    doAssert m.data[0] == "/:action/id"
    doAssert m.params["action"] == "action"

  block:
    let trie = newTrie()
    trie.add "/book/:id/title", "/book/:id/title"
    trie.add "/book/:author/age", "/book/:author/age"

    var m = trie.match "/book/id/title"
    doAssert m.data[0] == "/book/:id/title"
    doAssert m.params["author"] == "id"

    m = trie.match "/book/author/age"
    doAssert m.data[0] == "/book/:author/age"
    doAssert m.params["author"] == "author"
"""
