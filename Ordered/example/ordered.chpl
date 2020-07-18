use Ordered;
var t = new orderedSet(int, false, defaultComparator, setImpl.treap);
writeln(t);
for i in 1..6 {
  t.add(i);
  writeln(t);
}
writeln(t);

for i in 4..8 {
  writeln(t.remove(i));
  writeln(t);
}

var result: int;
t.predecessor(2, result);
writeln(result);
t.successor(2, result);
writeln(result);
writeln('these:');
for v in t {
  writeln(v);
}
