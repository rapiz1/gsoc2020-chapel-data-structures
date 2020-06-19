use Vector;
use ListNG;
var v:listng(int, false, impl.vector) = 1..8;
v.insert(2, 0);
writeln(v);
writeln(v.size);
v.insert(v.size, 0);
writeln(v);
writeln(v.size);
