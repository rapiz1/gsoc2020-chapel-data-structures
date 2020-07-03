use Treap;
var t = new treap(int);
writeln(t);
for i in 1..5 {
  t.add(i);
  writeln(t);
}
writeln(t);

for i in 3..6 {
  writeln(t.remove(i));
  writeln(t);
}
