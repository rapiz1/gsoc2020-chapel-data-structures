use Ordered;
use OsetTest;

config param impl: orderedImpl;

var s1 = new orderedSet(int, false, defaultComparator, impl);
var s2 = new orderedSet(testRecord, false, defaultComparator, impl);
var s3 = new orderedSet(borrowed testClass, false, defaultComparator, impl);

assert(s1.size == 0);
assert(s2.size == 0);
assert(s3.size == 0);
