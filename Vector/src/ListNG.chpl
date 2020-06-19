private use List;
private use Vector;
private use IO;
enum impl { vector, list };
proc getTypeFromEnumVal(param val, type eltType, param parSafe) type {
  if val == impl.vector then return vector(eltType, parSafe);
  if val == impl.list then return list(eltType, parSafe);
}
proc getInstanceFromEnumVal(param val, type eltType, param parSafe, other) {
  if val == impl.vector then return new vector(other, parSafe);
  if val == impl.list then return new list(other, parSafe);
}
record listng {
  type eltType;
  param parSafe = false;
  param implType = impl.vector;
  forwarding var instance: getTypeFromEnumVal(implType, eltType, parSafe);

  proc init(type eltType, param parSafe = false, param implType: impl = impl.vector) {
    this.eltType = eltType;
    this.parSafe = parSafe;
    this.implType = implType;
  }

  proc init=(other: listng(this.type.eltType, ?p)) {
    this.eltType = this.type.eltType;
    this.parSafe = this.type.parSafe;
    this.implType = this.type.implType;

    this.instance = getInstanceFromEnumVal(implType, eltType, parSafe, other.instance);
  }

  proc init=(other: [?d] this.type.eltType) {
    this.eltType = this.type.eltType;
    this.parSafe = this.type.parSafe;
    this.implType = this.type.implType;

    this.instance = getInstanceFromEnumVal(implType, eltType, parSafe, other);
  }

  proc init=(other: range(?t)) {

    this.eltType = this.type.eltType;
    this.parSafe = this.type.parSafe;
    this.implType = this.type.implType;

    this.instance = getInstanceFromEnumVal(implType, eltType, parSafe, other);
  }

  proc readWriteThis(ch: channel) throws {
    ch <~> instance;
  }

  proc requestCapacity(size: int) where implType == impl.list {
    compilerError("List doesn't support requestCapacity");
  }
};
