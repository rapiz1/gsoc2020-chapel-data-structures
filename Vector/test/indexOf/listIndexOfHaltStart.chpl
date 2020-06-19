private use ListNG;

config const testIters = 8;

var lst: listng(int);

for i in 1..testIters do
  lst.append(i);

var idx = lst.indexOf(testIters, -1, testIters-1);

