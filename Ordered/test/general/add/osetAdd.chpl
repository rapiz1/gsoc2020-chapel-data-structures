use Ordered;
config param impl: orderedImpl;
var oset = new orderedSet(int, false, defaultComparator, impl);
for i in 1..5 {
  oset.add(i);
}
writeln(oset);
