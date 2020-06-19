private use ListNG;

//
// Initialize a listng from another listng.
//
{
  var lst1: listng(int);
  for x in 1..8 do
    lst1.append(x);

  var lst2: listng(int) = lst1;

  // Both the long and short forms of `init=` should have the same type.
  var lst3 = lst2;
  assert(lst3.type == lst2.type);

  for (x, y) in zip(lst1, lst2) do
    assert(x == y);

  lst1.clear();

  assert(lst2.size > lst1.size);
  assert(lst1.size == 0);
}
