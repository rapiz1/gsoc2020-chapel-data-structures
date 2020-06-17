private use List;
private use Vector;
private use IO;
enum impl { vector, list };
proc getTypeFromEnumVal(param val, type eltType) type {
  if val == impl.vector then return vector(eltType);
  if val == impl.list then return list(eltType);
}
record listng {
  type eltType;
  param implType = impl.vector;
  forwarding var instance: getTypeFromEnumVal(implType, eltType);

  proc init(type eltType, param implType: impl = impl.vector) {
    this.eltType = eltType;
    this.implType = implType;
  }

  proc readWriteThis(ch: channel) throws {
    ch <~> instance;
  }

  proc requestCapacity(size: int) where implType == impl.list {
    compilerError("List doesn't support requestCapacity");
  }
};
