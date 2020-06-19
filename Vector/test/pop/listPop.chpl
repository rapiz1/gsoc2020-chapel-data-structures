private use ListNG;

config const testIters = 16;

var lst = new listng(int, true);

for i in 1..testIters do
  lst.append(i);

for i in 1..testIters by -1 {
  const elem = lst.pop();
  assert(elem == i);
}

