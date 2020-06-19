use ListNG;

config type listType = int;
config param listLock = true;

config const stop = 16;

var lst = new listng(listType, listLock);

for i in 1..stop do {
  var x = i:listType;
  lst.append(x);
}

writeln(lst);
