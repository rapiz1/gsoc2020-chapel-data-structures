private use ListNG;

config const testIters = 8;

var lst: listng(int, true);

const r = 1..testIters;

lst.extend(r);

for (x, y) in zip(r, lst) do
  assert(x == y);


