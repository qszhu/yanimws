import std/[
  htmlparser,
  parseutils,
  strutils,
  uri,
]

import ../server
import ../utils

export uri



const CONTENT_TYPE = "content-type"
const CONTENT_TYPE_JSON = "application/json"
const CONTENT_TYPE_FORM = "application/x-www-form-urlencoded"
const CONTENT_TYPE_MULTIPART = "multipart/form-data"

proc decodeEntity(s: string): string =
  let N = s.len
  var i = 0
  while i < N:
    if s[i] == '&':
      i += 1
      var e = ""
      while i < N and s[i] != ';':
        e &= s[i]
        i += 1
      let d = e.entityToUtf8
      if d.len > 0:
        result &= d
      else:
        result &= e
    else:
      result &= s[i]
    i += 1

proc parseFormUrlEncoded*(body: string): YaRequestKV =
  result = newYaRequestKV()
  var key, val = ""
  var consumed = 0
  while consumed < body.len:
    consumed += body.parseUntil(key, "=", consumed)
    consumed += 1
    consumed += body.parseUntil(val, "&", consumed)
    consumed += 1
    result[decodeUrl(key)] = decodeUrl(val)

proc tail(s: var string, n: int): string {.inline.} =
  s[max(0, s.len - n) ..< s.len]

proc parseMultiPart(rawBody: string, boundary: string, body: var YaRequestKV, files: var Table[string, YaRequestFile]) =
  let endBoundary = ("--" & boundary & "--").toLowerAscii
  let boundary = ("--" & boundary).toLowerAscii

  proc isBoundary(line: var string): bool =
    line.tail(boundary.len).toLowerAscii.endsWith(boundary)

  proc isEndBoundary(line: var string): bool =
    line.tail(endBoundary.len).toLowerAscii.endsWith(endBoundary)

  var line = ""
  var consumed = 0
  const LINESEP = "\r\n"
  proc readLine() =
    consumed += rawBody.parseUntil(line, LINESEP, consumed)
    consumed += 2

  proc parseKeys(): Table[string, string] =
    result = initTable[string, string]()
    for part in line.strip.split("; "):
      let parts = part.strip.split("=")
      if parts.len != 2: continue
      let k = parts[0]
      let v = parts[1][1 ..< ^1].decodeEntity
      result[k] = v

  var keys = initTable[string, string]()
  var sofar = newSeq[string]()
  while consumed < rawBody.len:
    readLine()
    if line.isBoundary or line.isEndBoundary:
      if sofar.len > 0:
        let content = sofar.join(LINESEP)
        sofar = newSeq[string]()

        if "filename" in keys:
          let filename = keys["filename"]
          let path = getTempFn(filename)
          writeFile(path, content)
          files[keys["name"]] = YaRequestFile(filename: filename, path: path)
        else:
          body[keys["name"]] = content

        keys = initTable[string, string]()

      if not line.isEndBoundary:
        # TODO: parse multipart headers
        readLine()
        keys = parseKeys()
        readLine()
        while line.len != 0:
          readLine()
    else:
      sofar.add line

proc BodyParser*(): YaHandler =
  return proc(c: YaContext) {.async, gcsafe.} =
    var contentType = ""
    try:
      contentType = c.request.headers[CONTENT_TYPE, 0]
    except:
      discard
    contentType = contentType.toLowerAscii

    if contentType.startsWith(CONTENT_TYPE_JSON):
      c.request.json = c.request.rawBody.parseJson
    elif contentType.startsWith(CONTENT_TYPE_FORM):
      c.request.body = parseFormUrlEncoded(c.request.rawBody)
    elif contentType.startsWith(CONTENT_TYPE_MULTIPART):
      let boundary = contentType.split("boundary=")[1]
      parseMultiPart(c.request.rawBody, boundary, c.request.body, c.request.files)

    waitFor c.next()



when isMainModule:
  block:
    let rawBody = """
--e1d2bd7dae64431686a9b20739de762a
Content-Disposition: form-data; name="fn"; filename="TODO.md"


--e1d2bd7dae64431686a9b20739de762a--

""".replace("\n", "\r\n")
    var body = newYaRequestKV()
    var files = initTable[string, YaRequestFile]()
    parseMultiPart(rawBody, "e1d2bd7dae64431686a9b20739de762a", body, files)
    doAssert body.len == 0
    doAssert files.len == 1
    doAssert "fn" in files and files["fn"].filename == "TODO.md"

  block:
    let rawBody = """
--ef635ed81574415d91c737d05d3a7f65
Content-Disposition: form-data; name="fn"; filename=".env"

abc
--ef635ed81574415d91c737d05d3a7f65
Content-Disposition: form-data; name="foo"

bar
--ef635ed81574415d91c737d05d3a7f65--
""".replace("\n", "\r\n")
    var body = newYaRequestKV()
    var files = initTable[string, YaRequestFile]()
    parseMultiPart(rawBody, "ef635ed81574415d91c737d05d3a7f65", body, files)
    doAssert body.len == 1
    doAssert "foo" in body and body["foo"] == "bar"
    doAssert files.len == 1
    doAssert "fn" in files and files["fn"].filename == ".env"

  block:
    let rawBody = """
--847e58f8524147778f59b97c874af158
Content-Disposition: form-data; name="foo"

bar
--847e58f8524147778f59b97c874af158
Content-Disposition: form-data; name="fn"; filename=".env"

abc
--847e58f8524147778f59b97c874af158--
""".replace("\n", "\r\n")
    var body = newYaRequestKV()
    var files = initTable[string, YaRequestFile]()
    parseMultiPart(rawBody, "847e58f8524147778f59b97c874af158", body, files)
    doAssert body.len == 1
    doAssert "foo" in body and body["foo"] == "bar"
    doAssert files.len == 1
    doAssert "fn" in files and files["fn"].filename == ".env"

  block:
    let rawBody = """
------WebKitFormBoundarypLop4GeYsrasJB7r
Content-Disposition: form-data; name="fn"; filename="&#27979;&#35797;.md"
Content-Type: text/markdown


------WebKitFormBoundarypLop4GeYsrasJB7r--
""".replace("\n", "\r\n")
    var body = newYaRequestKV()
    var files = initTable[string, YaRequestFile]()
    parseMultiPart(rawBody, "----WebKitFormBoundarypLop4GeYsrasJB7r", body, files)
    doAssert body.len == 0
    doAssert files.len == 1
    doAssert "fn" in files and files["fn"].filename == "测试.md"