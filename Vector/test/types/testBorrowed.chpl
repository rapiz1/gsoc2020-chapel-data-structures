import ListNGTest;

class T {
  var value = 0;
}

type t = borrowed T;

ListNGTest.testListNG(t);
