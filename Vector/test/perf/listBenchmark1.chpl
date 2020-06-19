//
// A performance test benchmarking common listng operations.
//

private use HaltWrappers;
private use ListNG;
private use Random;
private use Time;

type byte = int(8);
type testListNG = listng(byte, false);

config const isPerformanceTest: bool = false;
config const n0: int = 50000;

const n1: int = n0 / 1000;
const seed = 314159;

proc createListNG(size: int) {
  var result: testListNG;
  for i in 1..size do result.append(0:byte);
  return result;
}

proc warmup() {
  const size = if isPerformanceTest then n1 else n0;
  var lst1 = createListNG(size);
  var lst2 = createListNG(size);

  for (a, b) in zip(lst1, lst2) do a += b % 127;

  lst1.clear();
  lst2.clear();  
}

class Test {
  proc name(): string { pureVirtualMethodHalt(); }
  proc setup() {}
  proc test() { pureVirtualMethodHalt(); }

  proc run(): real {
    var tmr = new Timer();

    setup();

    tmr.start();
    test();
    tmr.stop();

    return tmr.elapsed();
  }

  proc output() {
    // Run tests even if we aren't `-performance`.
    const time = this.run();

    const msg = if isPerformanceTest
      then this.name() + " " + time:string
      else this.name();
    writeln(msg);
  }
}
  
class AppendFromEmpty: Test {
  var _lst: testListNG;

  override proc name() return "Append";
  override proc setup() { _lst.clear(); }

  override proc test() {
    for i in 1..n0 do _lst.append((i % 127):byte);
  }
}

class InsertFront: Test {
  // Use a smaller value for N because InsertFront is a O(n**2) operation.
  var _lst: testListNG;
 
  override proc name() return "InsertFront";
  override proc setup() { _lst = createListNG(1); }
  override proc test() {
    while _lst.size < n1 do _lst.insert(0, (_lst.size & 127):byte);
  }
}

class PopFromBack: Test {
  var _lst: testListNG;

  override proc name() return "PopBack";
  override proc setup() { _lst = createListNG(n0); }
  override proc test() {
    while !_lst.isEmpty() do _lst.pop();
  }
}

class PopFromFront: Test {
  var _lst: testListNG;

  override proc name() return "PopFront";
  // Use a smaller value for N because PopFront is O(n**2).
  override proc setup() { _lst = createListNG(n1); }
  override proc test() {
    while !_lst.isEmpty() do _lst.pop(0);
  }
}

class IterSerial: Test {
  var _lst: testListNG;

  override proc name() return "IterSerial";
  override proc setup() { _lst = createListNG(n0); }
  override proc test() {
    for x in _lst do x += 1;
  }
}

class IterParallel: Test {
  var _lst: testListNG;

  override proc name() return "IterParallel";
  override proc setup() { _lst = createListNG(n0); }
  override proc test() {
    forall x in _lst do x += 1;
  }
}
  
class RandomAccess1: Test {
  var _lst: testListNG;
  var _rnd: [0..#n0] int;

  override proc name() return "RandomAccess1";
  override proc setup() {
    _lst = createListNG(n0);
    // Set up a trace of random indices.
    fillRandom(_rnd, seed);
    _rnd = mod(_rnd, n0);
  }
  override proc test() {
    for r in _rnd do _lst[r] &= 0xFF:byte;
  }
}

class Clear: Test {
  var _lst: testListNG;

  override proc name() return "Clear";
  override proc setup() { _lst = createListNG(n0); }
  override proc test() {
    _lst.clear();
  }
}

proc main() {
  var tests: listng(owned Test);

  tests.append(new AppendFromEmpty());
  tests.append(new InsertFront());
  tests.append(new PopFromBack());
  tests.append(new PopFromFront());
  tests.append(new IterSerial());
  tests.append(new IterParallel());
  tests.append(new RandomAccess1());
  tests.append(new Clear());

  warmup();

  for tst in tests do
    tst.output();
}

