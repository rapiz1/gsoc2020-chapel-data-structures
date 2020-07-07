/*
  This module contains a implementation of Treap,
  which provides the functionality of OrderedSet.
*/
module Treap {
  import ChapelLocks;
  private use HaltWrappers;
  private use Sort;
  private use Random;
  private use IO;

  pragma "no doc"
  private param _sanityChecks = true;

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

  /*
    Helper procedure to get one random int
  */
  pragma "no doc"
  proc _random(): int {
    var rand: [0..0] int;
    fillRandom(rand);
    return rand[0];
  }

  pragma "no doc"
  class _treapNode {
    type eltType;
    var element: eltType;
    var rank, size: int;
    var parent: unmanaged _treapNode(eltType)?;
    var children: [0..1] unmanaged _treapNode(eltType)?;
    proc update() {
      size = 1;
      for child in children {
        if child != nil {
          size += child!.size;
        }
      }
    }
    proc destroy() {
      for child in children {
        if child != nil {
          child!.destroy();
          delete child;
        }
      }
    }
    proc sanityChecks() {
      if !_sanityChecks then return;
      for child in children {
        if child != nil {
          assert(child!.parent == this);
        }
      }
    }
  }

  record treap {
    type eltType;
    param parSafe = false;

    var comparator: record = defaultComparator;

    pragma "no doc"
    type nodeType = unmanaged _treapNode(eltType)?;
    pragma "no doc"
    var _root: nodeType = nil;

    pragma "no doc"
    var _lock$ = if parSafe then new _LockWrapper() else none;

    pragma "no doc"
    inline proc _enter() {
      if parSafe then
        on this {
          _lock$.lock();
        }
    }

    pragma "no doc"
    inline proc _leave() {
      if parSafe then
        on this {
          _lock$.unlock();
        }
    }

    proc deinit() {
      if _root != nil {
        _root!.destroy();
      }
    }

    /*
      Print one node together with its children
    */
    pragma "no doc"
    proc _writeNode(node: nodeType, ch: channel) throws {
      var ret:(int, int, int);
      ret[0] = node!.element;
      if node!.children[0] then ret[1] = node!.children[0]!.element;
      if node!.children[1] then ret[2] = node!.children[1]!.element;
      ch.write(ret);
    }

    /*
      The current number of elements contained in this set.
    */
    inline proc const size {
      var result = 0;

      on this {
        _enter();
        if _root != nil {
          result = _root.size;
        }
        _leave();
      }

      return result;
    }

    /*
      Visit elements in the left child, root, right child order
    */
    pragma "no doc"
    proc _lmrVisit(node: nodeType, ch: channel) throws {
      if node == nil {
        return;
      }
      else {
        node!.sanityChecks();
        _lmrVisit(node!.children[0], ch);
        ch.write(node!.element, ' ');
        _lmrVisit(node!.children[1], ch);
      }
    }

    /*
      Visit and output elements in order
    */
    pragma "no doc"
    proc _visit(ch: channel) throws {
      ch.write('[ ');
      _lmrVisit(_root, ch);
      ch.write(']');
    }


    /*
      Add a copy of the element `x` to this set. Does nothing if this set
      already contains an element equal to the value of `x`.

      :arg x: The element to add to this set.
    */
    proc ref add(in x: eltType) lifetime this < x {

      // Remove `on this` block because it prevents copy elision of `x` when
      // passed to `_addElem`. See #15808.
      _enter();
      _insert(_root, x, nil);
      _leave();
    }

    /*
      Returns `true` if the given element is a member of this set, and `false`
      otherwise.

      :arg x: The element to test for membership.
      :return: Whether or not the given element is a member of this set.
      :rtype: `bool`
    */
    proc const contains(const ref x: eltType): bool {
      var result = false;

      on this {
        _enter(); 
        result = _find(_root, x) == nil;
        _leave();
      }

      return result;
    }

    /*
      Helper procedure to make x becomes a child of y, in position pos
    */
    pragma "no doc"
    proc _link(x: nodeType, y: nodeType, pos: int) {
      if x != nil then
        x!.parent = y;
      if y != nil then
        y!.children[pos] = x;
    }

    /*
      The rotation will make the node.children[pos] becomes the new _root
    */
    pragma "no doc"
    proc _rotate(ref node: nodeType, pos: int) {
      var child = node!.children[pos];
      var parent = node!.parent;

      _link(child!.children[pos^1], node, pos);
      _link(node, child, pos^1);
      

      // Update the size field
      node!.update();
      child!.update();

      child!.parent = parent;
      node = child; // This is for change the node in its parent's children array
    }

    /*
      Helper procedure to locate a certain node
    */
    pragma "no doc"
    proc _find(ref node: nodeType, element: eltType) ref: nodeType
    lifetime return node {
      if node == nil then return node;
      var cmp = chpl_compare(element, node!.element, comparator);
      if cmp == 0 then return node;
      else if cmp < 0 then return _find(node!.children[0], element);
      else return _find(node!.children[1], element);
    }

    /*
      Compare wrapper
    */
    pragma "no doc"
    proc _compare(x: eltType, y: eltType) {
      return chpl_compare(x, y, comparator);
    }

    pragma "no doc"
    proc ref _insert(ref node: nodeType, element: eltType, parent: nodeType): bool {
      if node == nil {
        node = new nodeType(element, _random(), 1, parent);
        return true;
      }
      var cmp = _compare(element, node!.element);
      if cmp == 0 then return false;
      else {
        var result = false;
        var pos: int = cmp > 0;
        result = _insert(node!.children[pos], element, node);
        if node!.children[pos]!.rank > node!.rank {
          _rotate(node, pos);
        }
        node!.update();
        return result;
      }
    }

    proc ref _remove(ref node: nodeType, const ref x: eltType): bool {
      if node == nil then return false;
      var cmp = _compare(x, node!.element);
      if cmp == 0 {
        var children = node!.children;
        if children[0] == nil && children[1] == nil {
          // Leaf node, safely removed
          delete node;
          node = nil;
          return true;
        }

        // Choose one non-nil child
        var childPos = 0;
        if children[childPos] == nil {
          childPos ^= 1;
        }

        // Choose the one with greater rank
        if children[childPos^1] != nil {
          var anotherChildPos = childPos^1;
          if children[anotherChildPos]!.rank > children[childPos]!.rank {
            childPos = anotherChildPos;
          }
        }

        // Rotate the root down
        _rotate(node, childPos);

        // Remove the old root recursively
        var result = _remove(node!.children[childPos^1], x);
        node!.update();
        return result;
      }
      else {
        var pos = cmp > 0;
        var result = _remove(node!.children[pos], x);
        node!.update();
        return result;
      }
    }

    /*
      Attempt to remove the item from this set with a value equal to `x`. If
      an element equal to `x` was removed from this set, return `true`, else
      return `false` if no such value was found.

      .. warning::

        Removing an element from this set may invalidate existing references
        to the elements contained in this set.

      :arg x: The element to remove.
      :return: Whether or not an element equal to `x` was removed.
      :rtype: `bool`
    */
    proc ref remove(const ref x: eltType): bool {
      var result = false;

      on this {
        _enter();
        result = _remove(_root, x);
        _leave();
      }

      return result;
    }

    /*
      Clear the contents of this set.

      .. warning::

        Clearing the contents of this set will invalidate all existing
        references to the elements contained in this set.
    */
    proc ref clear() {
      on this {
        _enter();
        if _root != nil {
          _root!.destroy();
          delete _root;
          _root = nil;
        }
        _leave();
      }
    }

    /*
      Helper procedure to return predecessor/successor of one node
      if direction is 0, return predecessor
      else if 1, return successor
    */
    pragma "no doc"
    proc _neighbour(in node: nodeType, in direction: int) {
      // Assuming direction is 1, we're finding the successor
      if node == nil then return nil;
      if node!.children[direction] {
        // node has right child,
        // find the leftmost node in its right child tree 
        node = node!.children[direction];
        direction ^= 1;
        while node != nil && node!.children[direction] != nil {
          node = node!.children[direction];
        }
      }
      else {
        // node doesn't have right child,
        // find its first ancesstor whose left child tree it belongs to
        direction ^= 1;
        while node!.parent != nil && node!.parent!.children[direction] != node {
          node = node!.parent;
        }
        return node!.parent;
      }
      return node;
    }

    /*
      Find the predecessor of one element in the treap.
      Returns if there is such one element.
      If there is, store the result in `result`.

      :arg e: The element to base
      :type e: `eltType`

      :arg result: The destination to store the result
      :type result: `eltType`

      :return: if there is such one element
      :rtype: `bool`
    */
    proc predecessor(e: eltType, out result: eltType) {
      _enter();
      var baseNode = _find(_root, e);
      if baseNode == nil {
        _leave();
        return false;
      }

      var resultNode = _neighbour(baseNode, 0);
      if resultNode == nil {
        _leave();
        return false;
      }
      else {
        result = resultNode!.element;
        _leave();
        return true;
      }
    }
    
    /*
      Find the successor of one element in the treap.
      Returns if there is such one element.
      If there is, store the result in `result`.

      :arg e: The element to base
      :type e: `eltType`

      :arg result: The destination to store the result
      :type result: `eltType`

      :return: if there is such one element
      :rtype: `bool`
    */
    proc successor(e: eltType, out result: eltType) {
      _enter();
      var baseNode = _find(_root, e);
      if baseNode == nil {
        _leave();
        return false;
      }

      var resultNode = _neighbour(baseNode, 1);
      if resultNode == nil {
        _leave();
        return false;
      }
      else {
        result = resultNode!.element;
        _leave();
        return true;
      }
    }

    /*
      Returns the minimal element in the tree
    */
    pragma "no doc"
    proc _first() {
      var node = _root;
      while node != nil && node!.children[0] != nil {
        node = node!.children[0];
      }
      return node;
    }

    /*
      Iterate over the elements of this set. Yields constant references
      that cannot be modified.

      .. warning::

        Modifying this set while iterating over it may invalidate the
        references returned by an iterator and is considered undefined
        behavior.
      
      :yields: A constant reference to an element in this set.
    */
    iter const these() {
      var node = _first();
      while node != nil {
        yield node!.element;
        node = _neighbour(node, 1);
      }
    }

    /*
      Write the contents of this list to a channel.

      :arg ch: A channel to write to.
    */
    proc const writeThis(ch: channel) throws {
      _enter();
      _visit(ch);
      _leave();
    }

    /*
      Returns `true` if this set contains zero elements.

      :return: `true` if this set is empty.
      :rtype: `bool`
    */
    inline proc const isEmpty(): bool {
      var result = false;

      on this {
        _enter();
        result = _root == nil;
        _leave();
      }

      return result;
    }

    /*
      The current number of elements contained in this set.
    */
    inline proc const size {
      var result = 0;

      on this {
        _enter();
        if _root != nil then
          result = _root!.size;
        _leave();
      }

      return result;
    }

    /*
      Returns a new DefaultRectangular array containing a copy of each of the
      elements contained in this set. The elements of the returned array are
      not guaranteed to follow any particular ordering.

      :return: An array containing a copy of each of the elements in this set.
      :rtype: `[] eltType`
    */
    proc const toArray(): [] eltType {
      // May take locks non-locally...
      _enter(); defer _leave();

      var treapSize = 0;
      if _root != nil then treapSize = _root!.size;

      var result: [0..#treapSize] eltType;

      if !isCopyableType(eltType) then
        compilerError('Cannot create array because set element type ' +
                      eltType:string + ' is not copyable');

      on this {
        if treapSize != 0 {
          var count = 0;
          var array: [0..#treapSize] eltType;

          for x in this {
            array[count] = x;
            count += 1;
          }

          result = array;
        }
      }

      return result;
    }
  }
}