use ListNG;

config type listType = int;
config param listLock = true;
config const testIters = 16;

var lst = new listng(listType, listLock);

for i in 1..testIters by -1 do
  lst.append(i);

writeln(lst);

// Sort using default comparator.
lst.sort();

writeln(lst);
