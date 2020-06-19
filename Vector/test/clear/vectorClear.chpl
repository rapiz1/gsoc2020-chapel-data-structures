use Vector;
use ListNG;

var v = new listng(int, false, impl.vector);
writeln(v);

for i in 1..10 {
  v.append(i);
}

writeln(v);
v.clear();

writeln(v);
