use Ordered;
use OsetTest;

config param impl: setImpl;
config const testIters = 8;



proc doTest(type eltType) {
  var s1 = new orderedSet(eltType, false, defaultComparator, impl);
  var s2 = new orderedSet(eltType, false, defaultComparator, impl);
  var s3 = new orderedSet(eltType, false, defaultComparator, impl);
  var s4 = new orderedSet(eltType, false, defaultComparator, impl);

  assert(s1.size == s2.size == s3.size == 0);

  for i in 1..testIters {
    var x = i:eltType;
    s1.add(x);
  }

  for i in 1..(testIters * 2) {
    var x = i:eltType;
    s2.add(x);
  }

  s3 = s2;

  for x in s1 do
    assert(s3.remove(x));

  for x in s3 do
    assert(!s1.contains(x) && s2.contains(x));

  s4 = s1 | s3;

  assert(s4.size == s2.size);

  s1 |= s3;
  assert(s1 == s4);

  for x in s4 do
    assert(s2.contains(x));
}

doTest(int);
doTest(testRecord);