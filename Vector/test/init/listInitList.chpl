private use ListNG;

config const testIters = 8;

var lst1: listng(int);

for i in 1..testIters do
  lst1.append(i);

var lst2 = new listng(lst1);

for (x, y) in zip(lst1, lst2) do
  assert(x == y);

lst1.clear();

assert(!lst2.isEmpty());

