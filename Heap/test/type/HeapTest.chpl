use Heap;

class T {
  var value = 0;
}

proc <(left: T, right: T) {
  return left.value < right.value;
}

proc testHeap(type t) where isTuple(t) {
  var l = new heap(t);
  var x = (new t[0](1), new t[1](2));

  l.push(x);
  assert(l.size == 1);

  var value = l.top();
  l.pop();
  assert(l.size == 0);
}

proc testHeap(type t) {
  var l = new heap(t);

  var x: t = new t(1);

  l.push(x);
  assert(l.size == 1);

  var value = l.top();
  l.pop();
  assert(l.size == 0);

  if isUnmanagedClass(t) {
    delete x;
  }

}
