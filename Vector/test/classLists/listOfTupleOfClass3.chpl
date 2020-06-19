use ListNG;
class C { var x: int; }
var l = new listng((int, owned C));
for i in 1..5 {
  var t = (i, new C(i));
  l.append(t);
}
writeln(l);
