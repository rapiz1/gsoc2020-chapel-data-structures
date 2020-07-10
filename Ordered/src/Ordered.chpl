/* Documentation for Ordered */
module Ordered {
  private use Treap;
  private use IO;
  public use Sort only defaultComparator;
  enum orderedImpl {treap, skipList};

  proc getTypeFromEnumVal(param val, type eltType, param parSafe) type {
    if val == orderedImpl.treap then return treap(eltType, parSafe);
    //FIXME: Use skipList when avaliable
    if val == orderedImpl.skipList then return treap(eltType, parSafe);
  }
  proc getInstanceFromEnumVal(param val, type eltType, param parSafe, comparator: record = defaultComparator) {
    if val == orderedImpl.treap then return new treap(eltType, parSafe, comparator);
    //FIXME: Use skipList when avaliable
    if val == orderedImpl.skipList then return new treap(eltType, parSafe, comparator);
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

    /*
      Initialize this set with a copy of each of the elements contained in
      the set `other`. This set will inherit the `parSafe` value of the
      set `other`.

      :arg other: A set to initialize this set with.
    */
    proc init=(const ref other: orderedSet(?t)) lifetime this < other {
      this.eltType = t;
      this.parSafe = other.parSafe;
      this.instance = getInstanceFromEnumVal(this.implType, this.eltType, this.parSafe, other.instance.comparator); 

      this.complete();


      if !isCopyableType(eltType) then
        compilerError('Cannot initialize ' + this.type:string + ' from ' +
                      other.type:string + ' because element type ' +
                      eltType:string + ' is not copyable');

      for elem in other do instance._add(elem);
    }

    /*
      Write the contents of this set to a channel.

      :arg ch: A channel to write to.
    */
    proc const writeThis(ch: channel) throws {
      instance.writeThis(ch);
    }
  }

  /*
    Clear the contents of this set, then extend this now empty set with the
    elements contained in another set.

    .. warning::

      This will invalidate any references to elements previously contained in
      `lhs`.

    :arg lhs: The set to assign to.
    :arg rhs: The set to assign from. 
  */
  proc =(ref lhs: orderedSet(?t), rhs: orderedSet(?r)) {
    lhs.clear();
    for x in rhs {
      lhs.add(x);
    }
  }
}
