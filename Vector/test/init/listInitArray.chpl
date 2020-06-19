private use ListNG;

config const testIters = 8;

var arr: [1..testIters] int = 1..testIters;

var lst = new listng(arr);

for (x, y) in zip(arr, lst) do
  assert(x == y);


