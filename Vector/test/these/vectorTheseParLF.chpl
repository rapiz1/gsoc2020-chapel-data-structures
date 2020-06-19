use ListNG;

config const testIters = 8;

const arr: [1..testIters] int = 1..testIters;
var vec: listng(int, false, impl.vector) = arr;

forall (x, y) in zip(arr, vec) do
  assert(x == y);

forall (x, y) in zip(vec, arr) do
  assert(x == y);



