import std/[
  logging,
  os,
  strutils,
]

export os



const DOTENV_FN = ".env"

proc loadDotEnv*() =
  if not fileExists(DOTENV_FN): return

  var fi: File
  try:
    fi = open(DOTENV_FN)
    var line: string
    while readLine(fi, line):
      let p = line.find "="
      if p == -1:
        logging.warn "Invalid line: ", line
        continue

      let
        key = line[0 ..< p].strip
        val = line[p + 1 .. ^1].strip
      if key.startsWith("#"): continue

      logging.debug (key, val)
      putEnv(key, val)
  finally:
    if fi != nil: fi.close
