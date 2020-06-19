private use ListNG;

config const testIters = 8;

const r = 1..testIters;

var lst = new listng(r);

for (x, y) in zip(r, lst) do
  assert(x == y);

