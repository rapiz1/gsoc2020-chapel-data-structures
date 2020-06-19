private use ListNG;

config const testIters = 8;

var lst: listng(int);

for i in 1..testIters do
  lst.append(i);

for i in 1..testIters {
  const elem = lst.pop(0);
  assert(elem == i);
}


