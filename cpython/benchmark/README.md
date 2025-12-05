# Benchmark

New syntax expects a performance drain. Here is what I did to measure this.

## Pyperformance

I made two full pyperformance run. The run command is `python -m pyperformance run -o result.json`. We can ignore all the faster result, as a new syntax doesn't expect any performance improvement. The result presents in pyperformance_result and pyperformance_result_second_try, I captured the slower result in both files:

- **<= 5% slower**: async_generators, html5lib. logging_silent, unpickle_pure_python
- **> 10% slower**: python_startup, many_optionals

## Simple Python

I also runs a simple test_lexer_performance.py. For some reasons, my base's python performs very slowly consistently in this case. The prod version does show an expected decrease with this new syntax.

- **base**: 49.358424986945465
- **Python 3.13.7 (released version in my machine)**: 29.679710355121642
- **lamdef**: 33.55943052005023
   - 13% slower than **Python 3.13.7**
