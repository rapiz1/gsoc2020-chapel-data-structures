use ListNG;

type listType = int;
param listLock = true;


var lst: listng(listType, listLock);

writeln(lst.isEmpty());

for i in 1..5 do
  lst.append(i:listType);

writeln(lst.isEmpty());

lst.clear();

writeln(lst.isEmpty());
