use ListNG;

proc takeAll(l: listng(int)) {
  if (l.implType == impl.vector) {
    writeln('invoked on vector');
  }
  else if (l.implType == impl.list) {
    writeln('invoked on list');
  }
}

proc takeVector(l: listng(int, impl.vector)) {
  writeln('invoked on vector only');
}

var ldef = new listng(int);
for i in 1..9 { 
  ldef.append(i);
}

var l1 = new listng(int, impl.vector);
for i in 1..9 {
  l1.append(i);
}

var l2 = new listng(int, impl.list);
for i in 1..9 {
  l2.append(i);
}
writeln(ldef);
writeln(ldef.type:string);
ldef.requestCapacity(32);

writeln(l1);
writeln(l1.type:string);
l1.requestCapacity(32);
writeln(l1.capacity);

writeln(l2);
writeln(l2.type:string);
//l2.requestCapacity(32);

takeAll(ldef);
takeAll(l1);
takeAll(l2);
takeVector(l1);
//takeVector(l2);

/*
[1, 2, 3, 4, 5, 6, 7, 8, 9]
listng(int(64),vector)
[1, 2, 3, 4, 5, 6, 7, 8, 9]
listng(int(64),vector)
32
[1, 2, 3, 4, 5, 6, 7, 8, 9]
listng(int(64),list)
invoked on vector
invoked on vector
invoked on list
invoked on vector only
*/