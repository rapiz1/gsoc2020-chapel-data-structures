use Vector;
use ListNG;

var v = new listng(int, false, impl.vector);
for i in 0 .. 4 {
  v.append(i);
  writeln(v);
  assert(v.size == i+1);
}
