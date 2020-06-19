private use ListNG;

config const testIters = 8;

const arr: [1..testIters] int = 1..testIters;
var lst: listng(int) = arr;

forall (x, y) in zip(arr, lst) do
  assert(x == y);

forall (x, y) in zip(lst, arr) do
  assert(x == y);



