/*
 * Copyright 2020 Hewlett Packard Enterprise Development LP
 * Copyright 2004-2019 Cray Inc.
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
  This module contains the implementation of the vector type.

  Vector is a kind of list storing elements in a contiguous area
*/
module Vector {

  import ChapelLocks;
  private use HaltWrappers;
  private use Sort;

  pragma "no doc"
  private const _initialCapacity = 8;
  //
  // We can change the lock type later. Use a spinlock for now, even if it
  // is suboptimal in cases where long critical sections have high
  // contention (IE, lots of tasks trying to insert into the middle of this
  // vector, or any operation that is O(n)).
  //
  pragma "no doc"
  type _lockType = ChapelLocks.chpl_LocalSpinlock;

  //
  // Use a wrapper class to let vector methods have a const ref receiver even
  // when `parSafe` is `true` and the vector lock is used.
  //
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

  private use IO;

  record vector {
    param parSafe = false;

    type eltType;

    var size = 0;
    var capacity = 0;
    var _data [] eltType = nil;

    proc init(type eltType, param parSafe=false) {
      this.eltType = eltType;
      this.parSafe = parSafe;
      this.complete();
    }
    proc init=(other: list(this.type.eltType)) {
      if !isCopyableType(this.type.eltType) then
        compilerError("Cannot copy list with element type that " +
                      "cannot be copied");

      this.eltType = this.type.eltType;
      this.parSafe = this.type.parSafe;
      this.complete();

      _requestCapacity(other.size);
      _commonInitFromIterable(other);
    }
    proc init=(other: [?d] this.type.eltType) {
      if !isCopyableType(this.type.eltType) then
        compilerError("Cannot copy list with element type that " +
                      "cannot be copied");
      this.eltType = this.type.eltType;
      this.parSafe = this.type.parSafe;
      this.complete();

      _requestCapacity(#d);
      _commonInitFromIterable(other);
    }
    proc init=(other: vector(this.type.eltType)) {
      if !isCopyableType(this.type.eltType) then
        compilerError("Cannot copy list with element type that " +
                      "cannot be copied");
      this.eltType = this.type.eltType;
      this.parSafe = this.type.parSafe;
      this.complete();

      _requestCapacity(other.size);
      _commonInitFromIterable(other);
    }

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
    proc _commonInitFromIterable(iterable) {
      for x in iterable do {
        _append(x);
      }
    }

    pragma "no doc"
    proc ref _append(x: eltType) {
      _requestCapacity(size+1);
      _data[size++] = x;
    }

    /*
      Add an element to the end of this vector.

      :arg x: An element to append.
      :type x: `eltType`
    */
    proc ref append(x: eltType) {
      _enter();

      _append(x);

      _leave();
    }

    /*
      Returns `true` if this vector contains an element equal to the value of
      `x`, and `false` otherwise.

      :arg x: An element to search for.
      :type x: `eltType`

      :return: `true` if this vector contains `x`.
      :rtype: `bool`
    */
    proc const contains(x: eltType): bool {
      var result = false;

      _enter();

      for item in this do
        if item == x {
          result = true;
          break;
        }

      _leave();

      return result;
    }

    /*
      Returns a reference to the first item in this vector.

      .. warning::

        Calling this method on an empty vector will cause the currently running
        program to halt. If the `--fast` flag is used, no safety checks will
        be performed.

      :return: A reference to the first item in this vector.
      :rtype: `ref eltType`
    */
    proc ref first() ref {
      _enter();

      if boundsChecking && _size == 0 {
        _leave();
        boundsCheckHalt("Called \"vector.first\" on an empty vector.");
      }

      ref result = _data[0];
      _leave();

      return result;
    }

    /*
      Returns a reference to the last item in this vector.

      .. warning::

        Calling this method on an empty vector will cause the currently running
        program to halt. If the `--fast` flag is used, no safety checks will
        be performed.

      :return: A reference to the last item in this vector.
      :rtype: `ref eltType`
    */
    proc ref last() ref {
      _enter();

      if boundsChecking && _size == 0 {
        _leave();
        boundsCheckHalt("Called \"vector.last\" on an empty vector.");
      }
     
      ref result = _data[size-1];
      _leave();

      return result;  
    }

    /*
      Insert an element at a given position

      :returns: if succeed
    */
    //TODO:
    proc insert(idx: int, in x:eltType): bool {}

    /*
      Erase an element at a give position
    */
    //TODO:
    proc erase(pos: int) {}

    pragma "no doc"
    proc _requestCapacity(newCap: int) {
      if (capacity >= newCap) return;
      if (capacity == 0) {
        capacity = _initialCapacity;
      }
      while (capacity < newCap) {
        capacity *= 2;
      }

      var ndata = new [capacity] eltType;
      if (_data != nil) {
        for i in 0..#this.size {
          ndata[i] = _data[i];
        }
      }
      _data = ndata;
    }

    /*
      Request a change in capacity
    */
    proc requestCapacity(newCapacaity: int) {
      _enter();
      _requestCapacity(size);
      _leave();
    }

    /*
      Extend this list by appending a copy of each element contained in
      another list.

      :arg other: A list containing elements of the same type as those
        contained in this list.
      :type other: `list(eltType)`
    */
    proc ref extend(other: list(eltType, ?p)) lifetime this < other {
      //TODO:
      //FIXME: More overloads of extend
    }
    /*
      Pop the element at the end
    */
    //TODO:
    proc pop(): eltType {}

    /*
      Append an element at the end
    */
    //TODO:
    proc push(in x: eltType) {}

    /*
      Returns a new DefaultRectangular array containing a copy of each of the elements contained in this vector.
    */
    //TODO:
    proc toArray(): [] eltType {}

    //TODO:
    iter these() ref {}
  }
}
