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
  This module contains the implementation of the heap type.

  A heap is a specialized tree-based data structure
  that supports extracting the maximal or the minimal element quickly,
  which can serve as a priority queue.

  * Both `push` and `pop` operations are O(lgN).
  * Querying the top element is O(1).
  * Initialization from an array is O(N).
*/
module Heap {
  import ChapelLocks;
  private use HaltWrappers;
  private use List;

  public use Sort only defaultComparator, DefaultComparator,
                       reverseComparator, ReverseComparator;
  private use Sort;

  // The locker is borrowed from List.chpl
  // 
  // We can change the lock type later. Use a spinlock for now, even if it
  // is suboptimal in cases where long critical sections have high
  // contention (IE, lots of tasks trying to insert into the middle of this
  // list, or any operation that is O(n)).
  //
  pragma "no doc"
  type _lockType = ChapelLocks.chpl_LocalSpinlock;

  //
  // Use a wrapper class to let heap methods have a const ref receiver even
  // when `parSafe` is `true` and the list lock is used.
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

  proc _checkType(type eltType) {
    /*
    if isNilableClass(eltType) then
      compilerError("Cannot create heap with nilable type");
      */
  }
    
  record heap {

    /* The type of the elements contained in this heap. */
    type eltType;

    /*
      Comparator record that defines how the
      data is compared. The greatest element will be on the top.
    */
    var comparator: record;

    /* If `true`, this heap will perform parallel safe operations. */
    param parSafe = false;

    pragma "no doc"
    var _lock$ = if parSafe then new _LockWrapper() else none;

    /*
      Use a list to store elements.
    */
    pragma "no doc"
    var _data: list(eltType);

    /*
      Build the heap from elements that have been stored, from bottom to top
      in O(N)
    */
    pragma "no doc"
    proc _commonInitFromIterable(iterable)
    lifetime this < iterable {
      _data = new list(eltType);
      for x in iterable do
        _data.append(x);
      for i in 1 .. _data.size-1 by -1 {
        _heapify_down(i);
      }
    }

    /*
      Initializes an empty heap.

      :arg eltType: The type of the elements

      :arg comparator: `DefaultComparator` makes max-heap and `ReverseCompartor` makes a min-heap

      :arg parSafe: If `true`, this heap will use parallel safe operations.
      :type parSafe: `param bool`
    */
    proc init(type eltType, comparator: record = defaultComparator, param parSafe=false) {
      _checkType(eltType);
      this.eltType = eltType;
      this.comparator = comparator;
      this.parSafe = parSafe;
      this._data = new list(eltType);
    }

    /*
      Initializes a heap containing elements that are copy initialized from
      the elements contained in another heap.

      :arg other: The heap to initialize from.
    */
    proc init=(other: heap(this.type.eltType)) {
      _checkType(this.type.eltType);
      if !isCopyableType(this.type.eltType) then
        compilerError("Cannot copy heap with element type that cannot be copied");

      this.eltType = this.type.eltType;
      this.comparator = other.comparator;
      this.parSafe = this.type.parSafe;
      this.complete();
      _commonInitFromIterable(other._data);
    }

    /*
      Initializes a heap containing elements that are copy initialized from
      the elements contained in another list.

      :arg other: The list to initialize from.
    */
    proc init=(other: list(this.type.eltType, ?p)) {
      _checkType(this.type.eltType);
      if !isCopyableType(this.type.eltType) then
        compilerError("Cannot copy list with element type that cannot be copied");

      this.eltType = this.type.eltType;
      this.comparator = new this.type.comparator();
      this.parSafe = this.type.parSafe;
      this.complete();
      _commonInitFromIterable(other);
    }

    /*
      Initializes a heap containing elements that are copy initialized from
      the elements contained in an array.

      :arg other: The array to initialize from.
    */
    proc init=(other: [?d] this.type.eltType) {
      _checkType(this.type.eltType);
      if !isCopyableType(this.type.eltType) then
        compilerError("Cannot copy heap from array with element type that cannot be copied");

      this.eltType = this.type.eltType;
      this.comparator = new this.type.comparator();
      this.parSafe = this.type.parSafe;
      this.complete();
      _commonInitFromIterable(other);
    }

    /*
      Initializes a heap containing elements that are copy initialized from
      the elements yielded by a range.

      .. note::

        Attempting to initialize a heap from an unbounded range will trigger
        a compiler error.

      :arg other: The range to initialize from.
      :type other: `range(this.type.eltType)`
    */
    proc init=(other: range(this.type.eltType, ?b, ?d)) {
      _checkType(this.type.eltType);
      this.eltType = this.type.eltType;
      this.comparator = new this.type.comparator();
      this.parSafe = this.type.parSafe;

      if !isBoundedRange(other) {
        param e = this.type:string;
        param f = other.type:string;
        param msg = "Cannot init " + e + " from unbounded " + f;
        compilerError(msg);
      }

      this.complete();
      _commonInitFromIterable(other);
    }

    /*
      Locks operations
    */
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

    /*
      Return the size of the heap.

      :return: The size of the heap
      :rtype: int
    */
    proc size:int {
      _enter();
      var result = _data.size;
      _leave();
      return result;
    }

    /*
      Returns `true` if this heap contains zero elements.

      :return: `true` if this heap is empty.
      :rtype: `bool`
    */
    proc isEmpty():bool {
      _enter();
      var result = _data.isEmpty();
      _leave();
      return result;
    }

    /*
      Return the maximal element in the heap.

      :return: The maximal element in the heap
      :rtype: `eltType`

      .. note::
        *Maximal* is defined by ``comparator``. If a ``reverseComparator`` is passed to ``init``,
        the heap will return the minimal element.

    */
    proc top(): eltType {
      _enter();
      if (boundsChecking && isEmpty()) {
        boundsCheckHalt("Called \"heap.top\" on an empty heap.");
      }
      ref result = _data(0);
      _leave();
      return result;
    }

    /*
      Wrapper of comparing elements
    */
    pragma "no doc"
    proc _greater(x:eltType, y:eltType) {
      return chpl_compare(x, y, comparator) > 0;
    }

    /*
      helper procs to maintain the heap
    */
    pragma "no doc"
    proc _heapify_up(in pos:int) {
      while (pos) {
        var parent = pos / 2;
        if (_greater(_data[pos],_data[parent])) {
          _data[parent] <=> _data[pos];
          pos = parent;
        }
        else break;
      }
    }

    pragma "no doc"
    proc _heapify_down(in pos:int) {
      while (pos < _data.size) {
        // find the child node with greater value
        var greaterChild = pos*2;
        if (greaterChild >= _data.size) then break; // reach leaf node, break
        if (greaterChild + 1 < _data.size) {
          // if the right child node exists
          if (_greater(_data[greaterChild+1],_data[greaterChild])) {
            // if the right child is greater, then update the greaterChild
            greaterChild += 1;
          }
        }
        // if the greaterChild's value is greater than current node, then swap and continue
        if (_greater(_data[greaterChild],_data[pos])) {
          _data[greaterChild] <=> _data[pos];
          pos = greaterChild;
        }
        else break;
      }
    }

    /*
      Push an element into the heap

      :arg element: The element that will be pushed
      :type element: `eltType`
    */
    proc push(in element:eltType)
    lifetime this < element {
      _enter();
      _data.append(element);
      _heapify_up(_data.size-1);
      _leave();
    }

    /*
      Pop an element.

        .. note::
          This procedure does not return the element.

    */
    proc pop() {
      _enter();
      if (boundsChecking && isEmpty()) {
        boundsCheckHalt("Called \"heap.pop\" on an empty heap.");
      }
      _data(0) <=> _data(_data.size-1);
      _data.pop();
      _heapify_down(0);
      _leave();
    }
  }
  /*
    Make a heap from a list.

    :arg x: The list to initialize the heap from.
    :type x: `list(?t)`

    :arg comparator: The comparator type

    :rtype: heap(t, comparator)
  */
  proc makeHeap(x:list(?t), type comparator = DefaultComparator) {
    var h:heap(t, comparator) = x;
    return h;
  }
  /*
    Make a heap from a range

    :arg x: The range to initialize the heap from.
    :type x: `range`

    :arg comparator: The comparator type

    :rtype: heap(int, comparator)

      .. note::

        Attempting to initialize a heap from an unbounded range will trigger
        a compiler error.

  */
  proc makeHeap(x:range, type comparator = DefaultComparator) {
    var h:heap(int, comparator) = x;
    return h;
  }
  /*
    Make a heap from a array.

    :arg x: The array to initialize the heap from.
    :type x: `[?d] ?t`

    :arg comparator: The comparator type

    :rtype: heap(t, comparator)
  */
  proc makeHeap(x:[?d] ?t, type comparator = DefaultComparator) {
    var h:heap(t, comparator) = x;
    return h;
  }

  /*
    Push elements of a list into a heap.

    :arg x: The list of which elements is to push.
    :type x: `list(?t)`

    :arg h: The heap to push
    :type h: `heap(t)`
  */
  proc pushHeap(x:list(?t), ref h:heap(t)) {
    for e in x do
      h.push(e);
  }
  /*
    Push elements in a range into a heap.

    :arg x: The range of which elements is to push.
    :type x: `range`

    :arg h: The heap to push
    :type h: `heap(int)`
  */
  proc pushHeap(x:range, ref h:heap(int)) {
    for e in x do
      h.push(e);
  }
  /*
    Push elements in an array into a heap.

    :arg x: The array of which elements is to push.
    :type x: `[?d]?t`

    :arg h: The heap to push
    :type h: `heap(t)`
  */
  proc pushHeap(x:[?d] ?t, ref h:heap(t)) {
    for e in x do
      h.push(e);
  }

  /*
    Pop elements into a list.

    :arg h: The heap to pop
    :type h: `ref heap(t)`

    :return: A list containing all elements in the heap
    :rtype: `list(t)`
  */
  proc popHeap(ref h:heap(?t)) {
    var l = new list(t);
    while (!h.isEmpty()) {
      l.append(h.top());
      h.pop();
    }
    return l;
  }
}
