import std/[
  os,
  tempfiles,
]



proc getTempFn*(srcFn: string, dir = ""): string =
  let
    (_, _, ext) = splitFile(srcFn)
    (_, destFn) = createTempFile("", ext, dir)
  destFn
