use Heap;
use Sort;

config const testParam:int = 10;


proc rangeTest(comparator) {
  var myHeap = new heap(int, comparator);
  var myArr: [1..testParam] int;

  for i in 1..testParam {
    myHeap.push(i);
    myArr[i] = i;
  }

  for i in 1..testParam {
    writeln(myHeap.top());
    myHeap.pop();
  }
}

rangeTest(defaultComparator);
rangeTest(reverseComparator);