import std/[
  logging,
  os,
  sets,
  sequtils,
  strformat,
  strutils,
]

export os



const DOTENV_FN = ".env"
const DOTENV_SAFE_FN = ".env.example"

proc loadDotEnv*() =
  if not fileExists(DOTENV_FN) or not fileExists(DOTENV_SAFE_FN):
    raise newException(CatchableError, &"missing {DOTENV_FN} or {DOTENV_SAFE_FN}")

  var keys = readFile(DOTENV_SAFE_FN).strip
    .split("\n")
    .filterIt("=" in it)
    .filterIt(not it.startsWith("#"))
    .mapIt(it.strip.split("=")[0].strip)
    .toHashSet

  for line in readFile(DOTENV_FN).strip.split("\n"):
    if "=" notin line: continue

    let parts = line.split("=").mapIt(it.strip)
    let (k, v) = (parts[0], parts[1])
    if k.startsWith("#"): continue

    logging.debug (k, v)
    putEnv(k, v)
    keys.excl k

  if keys.len > 0:
    raise newException(CatchableError, &"missing keys: {keys}")
