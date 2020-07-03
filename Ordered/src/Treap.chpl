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
          delete child;
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
      Returns `true` if the given element is a member of this set, and `false`
      otherwise.

      :arg x: The element to test for membership.
      :return: Whether or not the given element is a member of this set.
      :rtype: `bool`
    */
    /*
    FIXME: Wait for _find to be fixed
    proc const contains(const ref x: eltType): bool {
      var result = false;

      on this {
        _enter(); 
        result = _find(_root, x) == nil;
        _leave();
      }

      return result;
    }
    */

    /*
      the rotation will make the node.children[pos] becomes the new _root
    */
    pragma "no doc"
    proc _rotate(ref node: nodeType, pos: int) {
      var child = node!.children[pos];

      node!.children[pos] = child!.children[pos^1];
      child!.children[pos^1] = node;

      // Update the size field
      node!.update();
      child!.update();

      node = child; // Update the root
    }

    /*
      Helper procedure to locate a certain node
    */
    /*
    FIXME: Why this failed to compile?
    pragma "no doc"
    proc _find(ref node: nodeType, element: eltType) ref: nodeType
    lifetime node = _root {
      if node == nil then return node;
      var cmp = chpl_compare(element, node!.element, comparator);
      if cmp == 0 then return node;
      else if cmp < 0 then return _find(node!.children[0], element);
      else return _find(node!.children[1], element);
    }
    */

    /*
      Compare wrapper
    */
    pragma "no doc"
    proc _compare(x: eltType, y: eltType) {
      return chpl_compare(x, y, comparator);
    }

    pragma "no doc"
    proc ref _insert(ref node: nodeType, element: eltType): bool {
      //TODO: Balance the treap
      if node == nil {
        node = new nodeType(element, _random(), 1);
        return true;
      }
      var cmp = _compare(element, node!.element);
      if cmp == 0 then return false;
      else {
        var result = false;
        var pos: int = cmp > 0;
        result = _insert(node!.children[pos], element);
        if node!.children[pos]!.rank > node!.rank {
          _rotate(node, pos);
        }
        node!.update();
        return result;
      }
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
      _insert(_root, x);
      _leave();
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
      Write the contents of this list to a channel.

      :arg ch: A channel to write to.
    */
    proc writeThis(ch: channel) throws {
      _enter();
      _visit(ch);
      _leave();
    }
  }
}
