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

/*
  This module contains the implementation of the orderedMap type 
  which is a container that stores key-value associations. 

  orderedMaps are not parallel safe by default, but can be made parallel safe by
  setting the param formal `parSafe` to true in any orderedMap constructor. When
  constructed from another orderedMap, the new orderedMap will inherit 
  the parallel safety mode of its originating orderedMap.

  The time compleixity of an orderedMap depends on the implementation it used.
  Treap supports insertion and deletion in O(lgN).
*/
module OrderedMap {
  import ChapelLocks;
  private use HaltWrappers;
  private use OrderedSet;
  private use IO;
  public use Sort only defaultComparator;

  // Lock code lifted from modules/standard/Lists.chpl.
  pragma "no doc"
  type _lockType = ChapelLocks.chpl_LocalSpinlock;

  pragma "no doc"
  class _LockWrapper {
    var lock$ = new _lockType();

    inline proc lock() {
      lock$.lock();
    }

    inline proc unlock() {
      lock$.unlock();
    }
  }

  /* Implementations supported */
  enum mapImpl {treap};

  /* The default implementation to use */
  param defaultImpl = mapImpl.treap;

  //TODO: Locking is handled outside. Remove `parSafe`.
  pragma "no doc"
  proc getTypeFromEnumVal(param val, type eltType, param parSafe) type {
    if val == mapImpl.treap then return Treap.treap(eltType, false);
  }

  pragma "no doc"
  proc getInstanceFromEnumVal(param val, type eltType, param parSafe,
                              comparator: record = defaultComparator) {
    if val == mapImpl.treap then return new Treap.treap(eltType, false, comparator);
  }

  pragma "no doc"
  proc _checkKeyType(type keyType) {
    if isGenericType(keyType) {
      compilerWarning("creating a orderedMap with key type " +
                      keyType:string);
      if isClassType(keyType) && !isGenericType(borrowed keyType) {
        compilerWarning("which now means class type with generic management");
      }
      compilerError("orderedMap key type cannot currently be generic");
    }
  }

  pragma "no doc"
  proc _checkValType(type valType) {
    if isGenericType(valType) {
      compilerWarning("creating a orderedMap with value type " +
                      valType:string);
      if isClassType(valType) && !isGenericType(borrowed valType) {
        compilerWarning("which now means class type with generic management");
      }
      compilerError("orderedMap value type cannot currently be generic");
    }
  }

  record orderedMap {
    /* Type of orderedMap keys. */
    type keyType;
    /* Type of orderedMap values. */
    type valType;

    /*
      The shared nilable class helps us to find one element with the key
      and without speicfiying the value
      See `contains`
    */
    pragma "no doc"
    class _valueWrapper {
      var val;
    }

    pragma "no doc"
    type _eltType = (keyType, shared _valueWrapper?);

    /* If `true`, this orderedSet will perform parallel safe operations. */
    param parSafe = false;

    /* The comparator used to compare keys */
    var comparator: record = defaultComparator;

    /* The implementation to use */
    param implType = defaultImpl;

    /* The underlying implementation */
    forwarding var instance: getTypeFromEnumVal(implType, _eltType, parSafe);

    pragma "no doc"
    var _lock$ = if parSafe then new _LockWrapper() else none;

    pragma "no doc"
    inline proc _enter() {
      if parSafe then
        _lock$.lock();
    }

    pragma "no doc"
    inline proc _leave() {
      if parSafe then
        _lock$.unlock();
    }

    pragma "no doc"
    record _keyComparator {
      var comparator: record;
      proc compare(a, b) {
        return comparator.compare(a[0], b[0]);
      }
    }

    /*
      Initializes an empty orderedMap containing keys and values of given types.

      :arg keyType: The type of the keys of this orderedMap.
      :arg valType: The type of the values of this orderedMap.
      :arg parSafe: If `true`, this orderedMap will use parallel safe operations.
      :type parSafe: bool
      :arg comparator: The comparator used to compare elements.
    */
    proc init(type keyType, type valType, param parSafe = false,
              comparator: record = defaultComparator,
              param implType: mapImpl = defaultImpl) {
      _checkKeyType(keyType);
      _checkValType(valType);

      this.keyType = keyType;
      this.valType = valType;
      this._eltType = (keyType, shared _valueWrapper(valType)?);
      this.parSafe = parSafe;
      this.comparator = new _keyComparator(comparator);
      this.implType = implType;

      this.instance = getInstanceFromEnumVal(implType, _eltType, parSafe,
                                              this.comparator); 
    }

    /*
      Initialize this orderedMap with a copy of each of the elements contained in
      the orderedMap `other`. This orderedMap will inherit the `parSafe` value of 
      the orderedMap `other`.

      :arg other: An orderedMap to initialize this orderedMap with.
    */
    proc init=(const ref other: orderedMap(?kt, ?vt)) lifetime this < other {
      if !isCopyableType(kt) || !isCopyableType(vt) then
        compilerError("initializing map with non-copyable type");

      this.keyType = kt;
      this.valType = vt;
      this._eltType = (keyType, shared _valueWrapper(valType)?);
      this.parSafe = other.parSafe;
      this.comparator = other.comparator;
      this.implType = other.implType;
      this.instance = getInstanceFromEnumVal(this.implType, this._eltType, this.parSafe, other.instance.comparator); 

      this.complete();
    }

    /*
      Clears the contents of this map.

      .. warning::

        Clearing the contents of this map will invalidate all existing
        references to the elements contained in this map.
    */
    proc clear() {
      _enter(); defer _leave();
      instance.clear();
    }

    /*
      The current number of keys contained in this map.
    */
    inline proc const size {
      _enter(); defer _leave();
      return instance.size;
    }

    /*
      Returns `true` if this map contains zero keys.

      :returns: `true` if this map is empty.
      :rtype: `bool`
    */
    inline proc const isEmpty(): bool {
      return size == 0;
    }

    /*
      Returns `true` if the given key is a member of this map, and `false`
      otherwise.

      :arg k: The key to test for membership.
      :type k: keyType

      :returns: Whether or not the given key is a member of this map.
      :rtype: `bool`
    */
    proc const contains(const k: keyType): bool {
      _enter(); defer _leave();
      return instance.contains((k, nil));
    }

    /*
      Updates this map with the contents of the other, overwriting the values
      for already-existing keys.

      :arg m: The other map
      :type m: map(keyType, valType)
    */
    proc update(pragma "intent ref maybe const formal"
                m: orderedMap(keyType, valType, parSafe)) {
      _enter(); defer _leave();

      if !isCopyableType(keyType) || !isCopyableType(valType) then
        compilerError("updating map with non-copyable type");

      for key in m.keys() {
        instance.remove((key, nil));
        instance.add((key, new shared _valueWrapper(m.getValue(key))?));
      }
    }

    /*
      Get the value mapped to the given key, or add the mapping if key does not
      exist.

      :arg k: The key to access
      :type k: keyType

      :returns: Reference to the value mapped to the given key.
    */
    proc ref this(k: keyType) ref where isDefaultInitializable(valType) {
      _enter(); defer _leave();

      if !instance.contains((k, nil)) then {
        var defaultValue: valType;
        instance.add((k, new shared _valueWrapper(defaultValue)?));
      } 

      ref e = instance._getReference((k, nil));

      ref result = e[1]!.val;
      return result;
    }

    pragma "no doc"
    proc const this(k: keyType) const
    where shouldReturnRvalueByValue(valType) && !isNonNilableClass(valType) {
      _enter(); defer _leave();

      // Could halt
      var e = instance._getValue((k, nil));

      const result = e[1]!.val;
      return result;
    }

    pragma "no doc"
    proc const this(k: keyType) const ref
    where shouldReturnRvalueByConstRef(valType) && !isNonNilableClass(valType) {
      _enter(); defer _leave();

      // Could halt
      var e = instance._getValue((k, nil));

      const ref result = e[1]!.val;
      return result;
    }

    pragma "no doc"
    proc const this(k: keyType)
    where isNonNilableClass(valType) {
      compilerError("Cannot access non-nilable class directly. Use an",
                    " appropriate accessor method instead.");
    }

    /* Get a borrowed reference to the element at position `k`.
     */
    proc getBorrowed(k: keyType) where isClass(valType) {
      _enter(); defer _leave();

      // This could halt
      var element = instance._getReferencee((k, nil));

      var result = element[1]!.val.borrow();

      return result;
    }

    /* Get a reference to the element at position `k`. This method is not
       available for non-nilable types.
     */
    proc getReference(k: keyType) ref
    where !isNonNilableClass(valType) {
      _enter(); defer _leave();

      // This could halt
      var element = instance._getReferencee((k, nil));

      ref result = element[1]!.val;

      return result;
    }

    /*
      Get a copy of the element stored at position `k`. This method is only
      available when a map's `valType` is a non-nilable class.
    */
    proc getValue(k: keyType) const {
      //TODO: Clean up
      /*
      if !isNonNilableClass(valType) then
        compilerError('getValue can only be called when a map value type ',
                      'is a non-nilable class');
                      */

      if isOwnedClass(valType) then
        compilerError('getValue cannot be called when a map value type ',
                      'is an owned class, use getBorrowed instead');

      _enter(); defer _leave();

      var result: (valType, shared _valueWrapper?);
      var found = instance.lowerBound((k, nil), result);
      if !found || result[0] != k then
        boundsCheckHalt("map index " + k:string + " out of bounds");
      return result[1]!.val;
    }
    /*
      Remove the element at position `k` from the map and return its value
    */
    proc getAndRemove(k: keyType) {
      _enter(); defer _leave();

      var result: (valType, shared _valueWrapper?);
      var found = instance.lowerBound((k, nil), result);
      if !found || result[0] != k then
        boundsCheckHalt("map index " + k:string + " out of bounds");

      instance.remove((k, nil));

      return result[1]!.val;
    }

    /*
      Iterates over the keys of this map. This is a shortcut for :iter:`keys`.

      :yields: A reference to one of the keys contained in this map.
    */
    iter these() const ref {
      for key in this.keys() {
        yield key;
      }
    }

    /*
      Iterates over the keys of this map.

      :yields: A reference to one of the keys contained in this map.
    */
    iter keys() const ref {
      for kv in instance {
          yield kv[0];
      }
    }

    /*
      Iterates over the key-value pairs of this map.

      :yields: A tuple of references to one of the key-value pairs contained in
               this map.
    */
    iter items() const ref {
      for kv in instance {
        yield (kv[0], kv[1]!.val);
      }
    }

    /*
      Writes the contents of this map to a channel. The format looks like:

        .. code-block:: chapel
    
           {k1: v1, k2: v2, .... , kn: vn}

      :arg ch: A channel to write to.
    */
    proc writeThis(ch: channel) throws {
      _enter(); defer _leave();
      var first = true;
      ch <~> "{";
      for kv in instance {
        if first {
          first = false;
        } else {
          ch <~> ", ";
        }
        ch <~> kv[0] <~> ": " <~> kv[1]!.val;
      }
      ch <~> "}";
    }

    /*
      Adds a key-value pair to the map. Method returns `false` if the key
      already exists in the map.

     :arg k: The key to add to the map
     :type k: keyType

     :arg v: The value that maps to ``k``
     :type k: valueType

     :returns: `true` if `k` was not in the map and added with value `v`.
               `false` otherwise.
     :rtype: bool
    */
    proc add(in k: keyType, in v: valType): bool lifetime this < v {
      _enter(); defer _leave();
      
      if instance.contains((k, nil)) {
        return false;
      }

      instance.add((k, new shared _valueWrapper(v)?));

      return true;
    }

    /*
      Sets the value associated with a key. Method returns `false` if the key
      does not exist in the map.

     :arg k: The key whose value needs to change
     :type k: keyType

     :arg v: The desired value to the key ``k``
     :type k: valueType

     :returns: `true` if `k` was in the map and its value is updated with `v`.
               `false` otherwise.
     :rtype: bool
    */
    proc set(k: keyType, in v: valType): bool {
      _enter(); defer _leave();

      if instance.contains((k, nil)) == false {
        return false;
      }

      instance.add((k, new shared _valueWrapper(v)?));

      return true;
    }

    /* If the map doesn't contain a value at position `k` add one and
       set it to `v`. If the map already contains a value at position
       `k`, update it to the value `v`.
     */
    proc addOrSet(in k: keyType, in v: valType) {
      _enter(); defer _leave();
      instance.remove((k, nil));
      instance.add((k, new shared _valueWrapper(v)?));
    }

    /*
      Removes a key-value pair from the map, with the given key.
      
     :arg k: The key to remove from the map

     :returns: `false` if `k` was not in the map.  `true` if it was and removed.
     :rtype: bool
    */
    proc remove(k: keyType): bool {
      _enter(); defer _leave();
      return instance.remove((k, nil));
    }
  }
}
