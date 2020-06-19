use Map;
use ListNG;

var m: map(string, listng(int));

m['a'] = new listng(int);

writeln(m);
// {a: []}

m['a'].append(1);
writeln(m);
// {a: [1]}

m['a'][0] = 2;
writeln(m);
// {a: [1]}
// but I expected:
// {a: [2]}
