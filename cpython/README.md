This file contains only modified files of cpython to support multiline lambda.

The head commit of CPython is [eb892868b31322d7cf271bc25923e14b1f67ae38](https://github.com/gkirchou/cpython/commit/eb892868b31322d7cf271bc25923e14b1f67ae38).
All the directories contains code based on it.
**before** contains the code based on it without any modification.
**after** contains the code that supports lamdef.


## Code Viewer

You can use diff tools to handle this locally, or use https://github.dev/note35/lamdef.

You can select two files (with the same name) in before and after, then the editor helps you compare the diff.


## Development

1. First time setup

```
# Copy those modified files into your cpython repo.
# (It's recommended to use diff tools (e.g., vimdiff) to handle conflicts.)

./configure --with-pydebug
```

2. Regular build

```
make regen-pegen regen-ast regen-keyword regen-token;  make -s -j $(nproc);
./python Lib/test/test_grammar.py
```

You can also try out directly with ./python

```
>>> a = lamdef(x):
...     b = lamdef(x):
...         return x
...     return b(1)
...     
>>> a(2)
1
>>> [lamdef(x):
...     return x
... ,
... lamdef(y):
...     return x+1
... ]
[<function <lambda> at 0x7f2d05aaf4d0>, <function <lambda> at 0x7f2d05aaee10>]
```

You can check `LamdDefTests` in **after/Lib/test/test_grammar.py** for more examples. 

## Benchmark

1. Build + Regression Testing.
```
# make distclean (needed when you've built before)
./configure --enable-optimizations --with-lto
# make regen-pegen regen-ast regen-keyword regen-token (needed for the first time)
make -s -j $(nproc);
# It's recommend to run the ./python againist to Lib/test/test_grammar.py to ensure the new syntax is handled.
./python Lib/test/test_grammar.py

```

2. Benchmark with pyperformance.
```
# Technical you should have two cpython environment: cpython (with lambdef) and cpython-base (with before) 
./python -m venv venv
source venv/bin/activate
pip install pyperformance
python -m pyperformance run -o result.json
python -m pyperf compare_to cpython-base/result.json cpython/result.json --table > pyperformance_result
```
