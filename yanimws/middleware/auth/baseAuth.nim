import ../../server



type
  BaseAuth* = ref object of RootObj
    key*, secret*: string

method genSign*(self: BaseAuth, c: YaContext): string {.base.} = discard
method checkSign*(self: BaseAuth, c: YaContext): bool {.base.} = discard
method signParams*(self: BaseAuth, params: JsonNode): JsonNode {.base.} = discard
