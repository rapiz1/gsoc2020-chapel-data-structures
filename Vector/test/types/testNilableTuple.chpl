import ListNGTest;

class T {
  var value = 0;
}

type t = (shared T?, shared T?);

ListNGTest.testListNG(t);
