use Vector;
use ListNG;

config const testIters = 10;

var v: listng(int, false, impl.vector) = 1..testIters;

for i in 1..testIters {
  assert(v.contains(i));
}

for i in -1..-testIters {
  assert(!v.contains(i));
}

v.clear();
for i in 1..testIters {
  assert(!v.contains(i));
}