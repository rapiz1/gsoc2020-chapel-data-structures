/* FIXME: This is a workaround for testing lowerBound. See https://github.com/chapel-lang/chapel/issues/16045
  It should be in the general folder and targeted at the orderedSet, instead of Treap
*/

use Treap;
use Random;
use Sort;

config const testIters = 128;

/* Find lowerBound in sorted arr */
proc lowerBound(arr: [?d] int, target: int, out result): bool {
  for x in arr {
    if x >= target {
      result = x;
      return true;
    }
  }
  return false;
}

proc doTest(arr: [?d] int) {
  var s1 = new treap(int, false, defaultComparator);

  for x in arr {
    s1.add(x);
  }

  sort(arr); 

  for i in 0..#testIters {
    var now = arr[i];

    var setResult: int;
    var setFound: bool = s1.lowerBound(now, setResult);

    var arrResult: int;
    var arrFound: bool = lowerBound(arr, now, arrResult);
    
    assert(setFound == arrFound);
    assert(!setFound || setResult == arrResult);

    now = arr[i] + 1;

    setFound = s1.lowerBound(now, setResult);

    arrFound = lowerBound(arr, now, arrResult);
    
    assert(setFound == arrFound);
    assert(!setFound || setResult == arrResult);
  }
}

var arr: [0..#testIters] int;
fillRandom(arr);
doTest(arr);

for i in 0..#testIters {
  arr[i] = i;
}
doTest(arr);
