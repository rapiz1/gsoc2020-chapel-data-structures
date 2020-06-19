use ListNG;

config const testIters = 137;

var vec1: listng(int, false, impl.vector);
var vec2: listng(int, true, impl.vector);

for i in 1..testIters do
  vec1.append(i);

forall x in vec1 do
  x *= 2;

// Vector 2 has `parSafe=true`, here.
forall x in vec1 with (ref vec2) do
  vec2.append(x);

vec2.sort();

for (x, y) in zip(vec1, vec2) do
  assert(x == y);


