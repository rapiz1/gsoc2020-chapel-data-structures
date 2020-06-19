private use ListNG;

config const testIters = 8;

var lst: listng(int, true);

for i in 1..testIters do
  lst.append(i);

assert(!lst.isEmpty());

ref elem = lst.first();

assert(elem == 1);

