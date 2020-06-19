use ListNG;

config const testIters = 4;

record innerListNG {
  var lst = new listng(int);

  proc deinit() {
    writeln(">> Destroying inner listng...");
    writeln(lst);
  }
}

record outerListNG {
  var lst = new listng(innerListNG);

  proc deinit() {
    writeln(">> Destroying outer listng...");
    writeln(lst);
  }
}

var outer = new outerListNG();

var inner = new innerListNG();
inner.lst.append(0);

for i in 1..testIters {
  outer.lst.append(inner);
}


