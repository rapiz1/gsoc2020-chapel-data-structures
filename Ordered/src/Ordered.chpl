/* Documentation for Ordered */
module Ordered {
  private use Treap;
  public use Sort only defaultComparator;
  enum orderedImpl {treap, skipList};

  proc getTypeFromEnumVal(param val, type eltType, param parSafe) type {
    if val == orderedImpl.treap then return treap(eltType, parSafe);
    if val == orderedImpl.skipList then return treap(eltType, parSafe);
    //if val == impl.list then return list(eltType, parSafe);
  }
  proc getInstanceFromEnumVal(param val, type eltType, param parSafe, comparator: record = defaultComparator) {
    if val == orderedImpl.treap then return new treap(eltType, parSafe, comparator);
    if val == orderedImpl.skipList then return new treap(eltType, parSafe, comparator);
    //if val == impl.list then return new list(other, parSafe);
  }

  param _defaultImpl = orderedImpl.treap;

  record orderedSet {
    type eltType;
    param parSafe = false;
    param implType = _defaultImpl;
    forwarding var instance: getTypeFromEnumVal(implType, eltType, parSafe);

    proc init(type eltType, param parSafe = false, comparator: record = defaultComparator,
              param implType: orderedImpl = _defaultImpl) {
      this.eltType = eltType;
      this.parSafe = parSafe;
      this.implType = implType;

      this.instance = getInstanceFromEnumVal(implType, eltType, parSafe, comparator); 
    }
  }
}
