private use Vector;
use ListNG;

config const testIters = 8;

var vec: listng(int, false, impl.vector);

for i in 1..testIters do
  vec.append(i);

for i in 1..testIters {
  const elem = vec.pop(0);
  assert(elem == i);
}


