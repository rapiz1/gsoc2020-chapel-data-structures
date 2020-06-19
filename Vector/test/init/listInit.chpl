use ListNG;

var lst1: listng(int, false);
var lst2: listng(int, true);

if lst1.parSafe == lst2.parSafe then
  compilerError("ListNGs have matching parSafe values");
