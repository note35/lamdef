import timeit

code_without_lamdef = """
data = [1, 2, 3, 4, 5]
result = {
    "key": [x for x in data],
    "value": (1, 2, 3)
}
""" * 1000

print(timeit.timeit(
    lambda: compile(code_without_lamdef, '', 'exec'), 
    number=1000
))
