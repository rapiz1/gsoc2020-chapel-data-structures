/*
  This test mirrors a similar test written for array.push_back, now rewritten
  to use ListNG.append instead.
*/

use ListNG;

var wrappedListNGs: listng(WrappedListNG);

const n = 10; // n is parsed from a file

extend(wrappedListNGs, n);

for i in 0..#n do
  wrappedListNGs[i].append(i);


record WrappedListNG {
  var ListNG: listng(int);

  proc append(node) {
    this.ListNG.append(node);
  }
}

proc extend(ref L: listng(?t, ?), n: int) {
  var default: t;
  for 1..n do
    L.append(default);
}


