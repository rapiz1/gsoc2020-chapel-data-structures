/*
 * Copyright 2004-2020 Hewlett Packard Enterprise Development LP
 * Other additional copyright holders may be indicated within.
 *
 * The entirety of this work is licensed under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 *
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* Documentation for Ordered */
module Ordered {
  private use Treap;
  private use IO;
  public use Sort only defaultComparator;
  enum setImpl {treap, skipList};

  pragma "no doc"
  proc getTypeFromEnumVal(param val, type eltType, param parSafe) type {
    if val == setImpl.treap then return treap(eltType, parSafe);
    //FIXME: Use skipList when avaliable
    if val == setImpl.skipList then return treap(eltType, parSafe);
  }

  pragma "no doc"
  proc getInstanceFromEnumVal(param val, type eltType, param parSafe, comparator: record = defaultComparator) {
    if val == setImpl.treap then return new treap(eltType, parSafe, comparator);
    //FIXME: Use skipList when avaliable
    if val == setImpl.skipList then return new treap(eltType, parSafe, comparator);
  }

  /* The default implementation to use */
  param _defaultImpl = setImpl.treap;

  record orderedSet {
    /* The type of the elements contained in this set. */
    type eltType;

    /* If `true`, this set will perform parallel safe operations. */
    param parSafe = false;

    /* The implementation to use */
    param implType = _defaultImpl;

    /* FIXME: This should be "no doc" but chpldoc will gives out an error */
    forwarding var instance: getTypeFromEnumVal(implType, eltType, parSafe);

    proc init(type eltType, param parSafe = false, comparator: record = defaultComparator,
              param implType: setImpl = _defaultImpl) {
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

    //FIXME: Workaround for https://github.com/chapel-lang/chapel/issues/16045
    pragma "no doc"
    proc const kth(k: int, out result: eltType): bool {
      return instance.kth(k, result);
    }

    pragma "no doc"
    proc const lowerBound(e: eltType, out result: eltType): bool {
      return instance.lowerBound(e, result);
    }

    pragma "no doc"
    proc const upperBound(e: eltType, out result: eltType): bool {
      return instance.upperBound(e, result);
    }

    pragma "no doc"
    proc const predecessor(e: eltType, out result: eltType) {
      return instance.predecessor(e, result);
    }

    pragma "no doc"
    proc const successor(e: eltType, out result: eltType) {
      return instance.successor(e, result);
    }
  }

  /*
    NOTE: Operators are borrowed from Set.chpl
  */

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

  /*
    Return a new set that contains the union of two sets.

    :arg a: A set to take the union of.
    :arg b: A set to take the union of.

    :return: A new set containing the union between `a` and `b`.
    :rtype: `orderedSet(?t)`
  */
  proc |(const ref a: orderedSet(?t), const ref b: orderedSet(t)): orderedSet(t) {
    var result: orderedSet(t, (a.parSafe || b.parSafe));

    result = a;
    result |= b;

    return result;
  }

  /*
    Add to the set `lhs` all the elements of `rhs`.

    :arg lhs: A set to take the union of and then assign to.
    :arg rhs: A set to take the union of.
  */
  proc |=(ref lhs: orderedSet(?t), const ref rhs: orderedSet(t)) {
    for x in rhs do
      lhs.add(x);
  }

  /*
    Return a new set that contains the union of two sets. Alias for the `|`
    operator.

    :arg a: A set to take the union of.
    :arg b: A set to take the union of.

    :return: A new set containing the union between `a` and `b`.
    :rtype: `orderedSet(?t)`
  */
  proc +(const ref a: orderedSet(?t), const ref b: orderedSet(t)): orderedSet(t) {
    return a | b;
  }

  /*
    Add to the set `lhs` all the elements of `rhs`.

    :arg lhs: A set to take the union of and then assign to.
    :arg rhs: A set to take the union of.
  */
  proc +=(ref lhs: orderedSet(?t), const ref rhs: orderedSet(t)) {
    lhs |= rhs;
  }

  /*
    Return a new set that contains the difference of two sets.

    :arg a: A set to take the difference of.
    :arg b: A set to take the difference of.

    :return: A new set containing the difference between `a` and `b`.
    :rtype: `orderedSet(t)`
  */
  proc -(const ref a: orderedSet(?t), const ref b: orderedSet(t)): orderedSet(t) {
    var result = new orderedSet(t, (a.parSafe || b.parSafe));

    if a.parSafe && b.parSafe {
      for x in a do
        if !b.contains(x) then
          result.add(x);
    } else {
      for x in a do
        if !b.contains(x) then
          result.add(x);
    }

    return result;
  }

  /*
    Remove from the set `lhs` the elements of `rhs`.

    .. warning::

      This will invalidate any references to elements previously contained in
      the set `lhs`.

    :arg lhs: A set to take the difference of and then assign to.
    :arg rhs: A set to take the difference of.
  */
  proc -=(ref lhs: orderedSet(?t), const ref rhs: orderedSet(t)) {
    if lhs.parSafe && rhs.parSafe {
      for x in rhs do
        lhs.remove(x);
    } else {
      for x in rhs do
        lhs.remove(x);
    }
  }

  /*
    Return a new set that contains the intersection of two sets.

    :arg a: A set to take the intersection of.
    :arg b: A set to take the intersection of.

    :return: A new set containing the intersection of `a` and `b`.
    :rtype: `orderedSet(t)`
  */
  proc &(const ref a: orderedSet(?t), const ref b: orderedSet(t)): orderedSet(t) {
    var result: orderedSet(t, (a.parSafe || b.parSafe));

    /* Iterate over the smaller set */
    if a.size <= b.size {
      if a.parSafe && b.parSafe {
        for x in a do
          if b.contains(x) then
            result.add(x);
      } else {
        for x in a do
          if b.contains(x) then
            result.add(x);
      }
    } else {
      if a.parSafe && b.parSafe {
        for x in b do
          if a.contains(x) then
            result.add(x);
      } else {
        for x in b do
          if a.contains(x) then
            result.add(x);
      }
    }

    return result;
  }

  /*
    Assign to the set `lhs` the set that is the intersection of `lhs` and
    `rhs`.

    .. warning::

      This will invalidate any references to elements previously contained in
      the set `lhs`.

    :arg lhs: A set to take the intersection of and then assign to.
    :arg rhs: A set to take the intersection of.
  */
  proc &=(ref lhs: orderedSet(?t), const ref rhs: orderedSet(t)) {
    /* Iterate over the smaller set.  But we can't remove things from
       lhs while iterating over it.  So use a temporary if lhs is
       significantly smaller than rhs; otherwise just iterate over rhs. */
    if lhs.size < 2 * rhs.size {
      var result: orderedSet(t, (lhs.parSafe || rhs.parSafe));

      if lhs.parSafe && rhs.parSafe {
        for x in lhs do
          if rhs.contains(x) then
            result.add(x);
      } else {
        for x in lhs do
          if rhs.contains(x) then
            result.add(x);
      }
      lhs = result;
    } else {
      if lhs.parSafe && rhs.parSafe {
        for x in rhs do
          lhs.remove(x);
      } else {
        for x in rhs do
          lhs.remove(x);
      }
    }
  }

  /*
    Return the symmetric difference of two sets.

    :arg a: A set to take the symmetric difference of.
    :arg b: A set to take the symmetric difference of.

    :return: A new set containing the symmetric difference of `a` and `b`.
    :rtype: `orderedSet(?t)`
  */
  proc ^(const ref a: orderedSet(?t), const ref b: orderedSet(t)): orderedSet(t) {
    var result: orderedSet(t, (a.parSafe || b.parSafe));

    /* Expect the loop in ^= to be more expensive than the loop in =,
       so arrange for the rhs of the ^= to be the smaller set. */
    if a.size <= b.size {
      result = b;
      result ^= a;
    } else {
      result = a;
      result ^= b;
    }

    return result;
  }

  /*
    Assign to the set `lhs` the set that is the symmetric difference of `lhs`
    and `rhs`.

    .. warning::

      This will invalidate any references to elements previously contained in
      the set `lhs`.

    :arg lhs: A set to take the symmetric difference of and then assign to.
    :arg rhs: A set to take the symmetric difference of.
  */
  proc ^=(ref lhs: orderedSet(?t), const ref rhs: orderedSet(t)) {
    if lhs.parSafe && rhs.parSafe {
      for x in rhs {
        if lhs.contains(x) {
          lhs.remove(x);
        } else {
          lhs.add(x);
        }
      }
    } else {
      for x in rhs {
        if lhs.contains(x) {
          lhs.remove(x);
        } else {
          lhs.add(x);
        }
      }
    }
  }

  /*
    Return `true` if the sets `a` and `b` are equal. That is, they are the
    same size and contain the same elements.

    :arg a: A set to compare.
    :arg b: A set to compare.

    :return: `true` if two sets are equal.
    :rtype: `bool`
  */
  proc ==(const ref a: orderedSet(?t), const ref b: orderedSet(t)): bool {
    if a.size != b.size then
      return false;

    var result = true;

    if a.parSafe && b.parSafe {
      for x in a do
        if !b.contains(x) then
          result = false;
    } else {
      for x in a do
        if !b.contains(x) then
          return false;
    }

    return result;
  }

  /*
    Return `true` if the sets `a` and `b` are not equal.

    :arg a: A set to compare.
    :arg b: A set to compare.

    :return: `true` if two sets are not equal.
    :rtype: `bool`
  */
  proc !=(const ref a: orderedSet(?t), const ref b: orderedSet(t)): bool {
    return !(a == b);
  }

  /*
    Return `true` if `a` is a proper subset of `b`.

    :arg a: A set to compare.
    :arg b: A set to compare.

    :return: `true` if `a` is a proper subset of `b`.
    :rtype: `bool`
  */
  proc <(const ref a: orderedSet(?t), const ref b: orderedSet(t)): bool {
    if a.size >= b.size then
      return false;
    return a <= b;
  }

  /*
    Return `true` if `a` is a subset of `b`.

    :arg a: A set to compare.
    :arg b: A set to compare.

    :return: `true` if `a` is a subset of `b`.
    :rtype: `bool`
  */
  proc <=(const ref a: orderedSet(?t), const ref b: orderedSet(t)): bool {
    if a.size > b.size then
      return false;

    var result = true;

    // TODO: Do we need to guard/make result atomic here?
    if a.parSafe && b.parSafe {
      for x in a do
        if !b.contains(x) then
          result = false;
    } else {
      for x in a do
        if !b.contains(x) then
          return false;
    }

    return result;
  }

  /*
    Return `true` if `a` is a proper superset of `b`.

    :arg a: A set to compare.
    :arg b: A set to compare.

    :return: `true` if `a` is a proper superset of `b`.
    :rtype: `bool`
  */
  proc >(const ref a: orderedSet(?t), const ref b: orderedSet(t)): bool {
    if a.size <= b.size then
      return false;
    return a >= b;
  }

  /*
    Return `true` if `a` is a superset of `b`.

    :arg a: A set to compare.
    :arg b: A set to compare.

    :return: `true` if `a` is a superset of `b`.
    :rtype: `bool`
  */
  proc >=(const ref a: orderedSet(?t), const ref b: orderedSet(t)): bool {
    if a.size < b.size then
      return false;

    var result = true;

    if a.parSafe && b.parSafe {
      for x in b do
        if !a.contains(x) then
          result = false;
    } else {
      for x in b do
        if !a.contains(x) then
          return false;
    }

    return result;
  }
}
