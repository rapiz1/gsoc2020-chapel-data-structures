private use ListNG;

config const testIters = 8;

var lst: listng(int) = 1..testIters;

for i in 1..testIters do
  assert(lst.contains(i));

for i in -1..-testIters do
  assert(!lst.contains(i));

lst.clear();

for i in 1..testIters do
  assert(!lst.contains(i));

