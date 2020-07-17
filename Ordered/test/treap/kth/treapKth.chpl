/* FIXME: This is a workaround for testing kth. See https://github.com/chapel-lang/chapel/issues/16045
  It should be in the general folder and targeted at the orderedSet, instead of Treap
*/

use Treap;
use Random;
use Sort;

config const testIters = 128;

proc doTest(arr: [?d] int) {
  var s1 = new treap(int, false, defaultComparator);

  for x in arr {
    s1.add(x);
  }

  sort(arr); 

  for i in 0..#testIters {
    var now = arr[i];

    var setResult: int;
    var setFound: bool = s1.kth(i+1, setResult);

    assert(setFound);
    assert(setResult == now);

    assert(s1.kth(i + 1 + testIters, setResult) == false);
  }
}

var arr: [0..#testIters] int;
fillRandom(arr);
doTest(arr);

for i in 0..#testIters {
  arr[i] = i;
}
doTest(arr);
