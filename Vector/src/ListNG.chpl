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
param _defaultImpl = impl.vector;
record listng {
  type eltType;
  param parSafe = false;
  param implType = _defaultImpl;
  forwarding var instance: getTypeFromEnumVal(implType, eltType, parSafe);

  proc init(type eltType, param parSafe = false, param implType: impl = _defaultImpl) {
    this.eltType = eltType;
    this.parSafe = parSafe;
    this.implType = implType;
  }

  proc init(other: [?d] ?t, param parSafe = false, param implType: impl = _defaultImpl) {
    this.eltType = t;
    this.parSafe = parSafe;
    this.implType = implType;
    this.instance = getInstanceFromEnumVal(implType, eltType, parSafe, other);
  }

  proc init(other: range(?t), param parSafe = false, param implType: impl = _defaultImpl) {
    this.eltType = t;
    this.parSafe = parSafe;
    this.implType = implType;
    this.instance = getInstanceFromEnumVal(implType, eltType, parSafe, other);
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

  proc ref extend(ref other: listng(eltType)) {
    instance.extend(other.instance);
  }

  proc readWriteThis(ch: channel) throws {
    ch <~> instance;
  }

  proc requestCapacity(size: int) where implType == impl.list {
    compilerError("List doesn't support requestCapacity");
  }
};

proc =(ref lhs: listng(?t), ref rhs: listng(t)) {
  lhs.instance = rhs.instance;
}

proc ==(lhs: listng(?t), rhs: listng(t)) {
  return lhs.instance == rhs.instance;
}

proc !=(lhs: listng(?t), rhs: listng(t)) {
  return lhs.instance != rhs.instance;
}