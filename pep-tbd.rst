PEP: TBD
Title: Typed Anonymous Functions
Version: $Revision$
Last-Modified: $Date$
Author: Kir Chou <kirchou@google.com>
Status: Draft
Type: Standards Track
Content-Type: text/x-rst
Created: 05-Dec-2025
Python-Version: 3.15
Post-History: 05-Dec-2025
Replaces:
Superseded-By:
Resolution:


Abstract
========

This PEP proposes a new syntax based on the [Off-side Rule](https://en.wikipedia.org/wiki/Off-side_rule) for creating anonymous functions that fully supports type hints and multi-line statements. While ``lambda`` expressions have served Python for decades, their inability to accept type annotations has created a significant gap in Python's modern type-safety ecosystem. Leveraging the flexibility of the [PEG parser](https://peps.python.org/pep-0617/), this proposal introduces a clean, statement-based anonymous function syntax (tentatively ``lamdef``). This feature aims to improve code locality and readability for callback-heavy patterns while aligning with the community's evolving interpretation of the Zen of Python: prioritizing explicit typing and practicality in an increasingly large-scale codebase.


Motivation
==========

The Limitation of Lambda 
------------------------

Back in 2005, Guido van Rossum expressed a preference for the clarity of named ``def`` statements over introducing multi-line lambdas (in the article titled "[The Fate of Reduce() and Lambda()](https://www.artima.com/weblogs/viewpost.jsp?thread=98196)"). At the time, this design choice prioritized readability and simplicity in a purely dynamic language.

However, the Python landscape has evolved significantly since then. With the introduction of [Type Hints](https://peps.python.org/pep-0484/), static analysis has become central to modern development. While ``def`` has adapted to support annotations, ``lambda`` remains unchanged. This discrepancy creates a usability gap in typed codebases, where anonymous functions cannot participate in type safety.

Furthermore, extending the existing ``lambda`` syntax to support types presents a technical challenge known as "colon collision." The parser faces ambiguity in distinguishing the colon used for type annotations from the colon marking the start of the ``lambda`` body::

        # SyntaxError: invalid syntax
        # Which colon terminates the parameter list?
        a = lambda x: int: x + 1

The Type Safety Gap
-------------------

Today's development experience, static analysis, and maintainability heavily rely on type hints. However, the inability of ``lambda`` expressions to support type annotations presents a challenge. This limitation compels developers to either use untyped code (which increases the risk of bugs) or define verbose, named functions (which can clutter the namespace) when dealing with elements like callbacks in a strongly typed environment.

`lambda` approach (Untyped)::

    # Type checker cannot infer the type of 'user', treating it as 'Any'.
    # No error is reported if 'user' has no 'is_active' attribute.
    filter(lambda user: user.is_active, users)

`def` approach (Typed and disconnected)::

    def _is_active_user(user: User) -> bool:
        return user.is_active

    # Logic is separated from the call site.
    filter(_is_active_user, users)

Proposed `lamdef` approach (Typed and localized)::

    filter(lamdef(user: User) -> bool:
        return user.is_active
    , users)

The Readability Gap
-------------------

The reliance on callbacks in use cases, combined with the constraints of ``lambda`` functions, often results in overly complex and hard-to-read code.

Scenario: Complex Conditional Logic
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A typical illustration of complex conditional logic is found in common Pandas transformations.

``lambda`` approach (Unreadable)::

    df['status'] = df.apply(
        lambda r: "Premium" if r['score'] > 90 else ("Active" if r['score'] > 50 else "Inactive"),
        axis=1
    )

Proposed ``lamdef`` solution (Typed and structured)::

    df['status'] = df.apply(lamdef(row: Series) -> str:
        score = row['score']
        if score > 90:
            return "Premium"
        if score > 50:
            return "Active"
        return "Inactive"
    , axis=1)


Scenario: Method Chaining
~~~~~~~~~~~~~~~~~~~~~~~~~

In fluent interfaces (like ORMs or data streams), logic is often passed through a chain of calls. When business logic involves multiple conditions, ``lambda`` forces developers to compress logic into unreadable, nested expressions.

``lambda`` approach (Unreadable)::

    result = (
        users
            .filter(lambda u: u.is_active and (datetime.now() - u.last_login).days < 30)
            .sort(lambda u: u.spend * -1)
            .map(lambda u: "VIP" if u.spend > 1000 else ("Regular" if u.spend > 100 else "New")))

Proposed ``lamdef`` solution (Typed and structured)::

    result = users.filter(
        lamdef(u: User) -> bool:
            is_recent = (datetime.now() - u.last_login).days < 30
            return u.is_active and is_recent
    ).sort(
        lamdef(u: User) -> int:
            return u.spend * -1
    ).map(
        lamdef(u: User) -> str:
            if u.spend > 1000:
                return "VIP"
            if u.spend > 100:
                return "Regular"
            return "New"
    )


Scenario: Event-driven Programming
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In event-driven programming (e.g., declarative UI frameworks), callbacks often require ensuring specific execution order or resource cleanup.

Given a toggling a loading spinner example. ``lambda`` cannot support try...finally blocks or multiple statements. Developers are often forced to use "list of callables" patterns or fragile list comprehensions to achieve sequential logic.

``lambda`` approach (Fragile)::

    # The "List Comprehension Hack" attempts to execute multiple side effects.
    Button(
        text="Submit",
        on_click=lambda: [
            ui.update(loading=True),
            api.submit(form.data),
            ui.update(loading=False)  # Loading spinner is not stopped when api.submit failed.
        ]
    )

Proposed ``lamdef`` solution (Typed and robust)::

    Button(
        text="Submit",
        on_click=lamdef() -> None:
            ui.update(loading=True)
            try:
                result = api.submit(form.data)
                if result.is_success:
                    ui.show_toast("Success!")
                else:
                    ui.show_error("Failed")
            finally:
                ui.update(loading=False)
    )


Scenario: Structural Pattern Matching Factories
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Structural Pattern Matching is often used to implement factories that return callbacks. When the logic involves multiple steps or side effects, ``lambda`` is insufficient.

Currently, developers are forced to define named functions for the efficiency consideration. This separates the logic from the ``case`` clause (breaking locality) and pollutes the local namespace with disposable function names.

``lambda`` approach (Disconnected)::

    def get_validator(rule: str) -> Callable[[str], bool]:
        def _validate_email(s:str) -> bool:
            if "@" not in s: return False
            user, domain = s.split("@", 1)
            return bool(user) and "." in domain

        def _validate_sku(s: str) -> bool:
            parts = s.split("-")
            return len(parts) == 2 and parts[1].isdigit()

        def _validate_unknown(s: str) -> bool:
            print(f"Warning: Unknown rule '{rule}'")
            return False

        match rule:
            case "email":
                return _validate_email
            case "sku":
                return _validate_sku
            case _:
                return _validate_unknown

Proposed ``lamdef`` solution (Localized)::

    def get_validator(rule: str) -> Callable[[str], bool]:
        match rule:
            case "email":
                return lamdef(s: str) -> bool:
                    if "@" not in s:
                        return False
                    user, domain = s.split("@", 1)
                    return bool(user) and "." in domain

            case "sku":
                return lamdef(s: str) -> bool:
                    parts = s.split("-")
                    return len(parts) == 2 and parts[1].isdigit()

            case _:
                return lamdef(s: str) -> bool:
                    print(f"Warning: Unknown rule '{rule}'")
                    return False

Proposal
========

New soft keyword: Lamdef
------------------------

We propose a new **soft keyword**, tentatively named ``lamdef``.

A ``lamdef`` is an **expression** that creates a new function object. It is designed to be syntactically similar to ``def`` to support type hints naturally, but it functions as an expression that returns a value, rather than a statement that binds a name.

Key characteristics:

1.  **Expression Context:** It produces a function object in-place.
2.  **Soft Keyword:** ``lamdef`` is reserved only in this specific grammar context. It remains a valid variable name in all other contexts, ensuring **zero backward compatibility breakage**.
3.  **Statement Body:** Unlike ``lambda``, the body is a full block of statements, identical to a standard function body.
4.  **Type Hints:** Full support.

Formal Grammar
--------------

::

    compound_stmt[stmt_ty]:
        ...
        | &(NAME '=' "lamdef") lamdef_stmt
        | &('return' "lamdef") lamdef_return_stmt

    expression[expr_ty] (memo):
        | invalid_expression
        | invalid_legacy_expression
        | &"lamdef" lamdef_expr
        ...

    lamdef_stmt[stmt_ty]:
        | a=NAME '=' b= lamdef_expr { _PyAST_Assign(...) }

    lamdef_return_stmt[stmt_ty]:
        | 'return' a=lamdef_expr { _PyAST_Return(a, EXTRA) }

    lamdef_expr[expr_ty]:
        | "lamdef" '(' params=[params] ')' a=['->' z=expression { z }] ':' body=lamdef_body { _PyAST_Lamdef(...) }

    lamdef_body[asdl_stmt_seq*]:
        | NEWLINE INDENT a=statements DEDENT { a }

Detailed Specification
----------------------

The syntax and behavior of ``lamdef`` are strictly defined to ensure consistency with standard Python statements while operating within an expression context. The following rules dictate legal usage.

1. Single-line Lamdef
~~~~~~~~~~~~~~~~~~~~~

Reserve and ban due to the semantic consistency considerations.

2. Multi-line Lamdef (Top-level)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A very basic case::

    f = lamdef(x):
        """doc"""
        y = x + 1
        return y

    f(1)  # returns 2

Same as ``def``, if you don't return, ``lamdef`` returns ``None``::

    f = lamdef(x):
        x + 1

    f(1)  # returns None

Same as ``def``, a function can have zero arguments::

    f = lamdef():
        return 1

    f(1)  # returns 1

Same as ``def``, a function handles ``*args`` and ``**kwargs``::

    f = lamdef(*args, **kwargs):
        return (args, kwargs)

    f(1, 2, c=3)  # ((1, 2), {'c': 3})

Same as ``def``, unreachable code after the return is ignored::

    f = lamdef(x):
            return x
            + 1

    f(1)  # returns 1

Same as a function object, you can call a ``lamdef`` right after the declaration::

    (lamdef(x):
        return x
    )(1)  # returns 1

Comma is handled as ``def``::

    f = lamdef(x):
        return x,

    f(1)  # returns (1,)

Nested ``lamdef`` expressions are supported, enabling patterns like currying::

    f = lamdef(x):
        return lamdef(y):
            return x + y
            
    f(1)(2)  # 3

Variable scoping and closures behave identically to standard ``def`` statements, including support for the ``nonlocal`` keyword::

    def make_counter():
        counter = 0
        return lamdef():
            nonlocal counter
            counter += 1
            return counter
            
    c = make_counter()
    c()  # 1
    c()  # 2

``lamdef`` can be added into f-string and t-string::

    template = t"<div>{(
        lamdef(name: str) -> str:
            if name == "Admin":
                return "Welcome, Admin"
            return f"Hello, {name}"
    )("Alice")}</div>"

3. Multi-line Lamdef (Container)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A single element declaration for ``lamdef`` in containers::

    # A list with one anonymous function, it returns its argument.
    [lamdef(x):
        return x
    ]

    # A list with one anonymous function, it returns a tuple.
    [lamdef(x):
        return x,
    ]

    # A dict with a lamdef value.
    {
        "key": lamdef(x):
            y = x + 1
            return y
    }

    # A generator with two lamdef.
    l = (lamdef(x):
        return x
    for i in range(2))

Exception: Comma is handled as ``def`` before the next newline::

    # A list with one element.
    [lamdef(x):
        return x
    ,]

    # A list with one element, the element returns a tuple.
    [lamdef(x):
        return x,
    ,]

    # A list with two elements, both elements return a tuple.
    [lamdef(x):
        return x,
    , lamdef(x):
        return x+1,
    ]


Closing delimiters are handled after ``lamdef``::

    # Not OK
    [lamdef(x):
        return x]

    # OK
    [lamdef(x):
        return x
    ]

To make the parser handle the syntax consistently, the syntactic delimiter belonging to the outer scope (such as `]`, `}`, `)`, `,`, or `:`) must appear at the outer indentation level::

    # Not OK
    [lamdef(x):
        return x,
        ]

    # OK
    [lamdef(x):
        return x,
        ]

    # Not OK
    [lamdef(x):
        return x,
        ,]

    # OK
    [lamdef(x):
        return x,
    ,]

    # Not OK
    {
        lamdef(x) -> x:
            return y
        : 1
    }

    # OK: A dict with a lamdef key
    {
        lamdef(x) -> x:
            return y
    : 1
    }

Heterogeneous container follows the Off-side Rule::

    # A normal case.
    [1
    , lamdef(x):
      return x,
    , "s"]

    # A complex case.
    [1,
                    lamdef(x): 
                        return x
    ,
            "two", lamdef(x):
                        return x
    , "three",
    ]

Nested container follows the Off-side Rule::

    data = [
       [lamdef(x):
            return x
    ], [lamdef(x):
            return x 
    ]
    ]

Generator follows the Off-side Rule and behaves late binding (same as ``def``)::

    g = [lamdef():
            return i
    for i in range(3)]

    [f() for f in fs]  # [2, 2, 2]

Type System 
-----------

A very basic case with type hints::

    f = lamdef(x: int) -> int:
        """doc"""
        y = x + 1
        return y

``lamdef`` shares the same underlying type as ``lambda``::

    assert isinstance(f, Callable)
    assert type(f) is type(lambda: None)

``lamdef`` preserves the type annotations::

    f.__annotations__  # {'x': <class 'int'>, 'return': <class 'int'>}

Runtime's ``reveal_type()``::

    reveal_type(f)  # 'function' <function <lambda> at 0x...>

Static type checkers' ``reveal_type()``::

    reveal_type(f)  # def (x: builtins.int) -> builtins.str

Therefore, static type checkers are expected to detect type mismatch cases, for example::

    f = lamdef(x: int) -> int:
        return "oops"  # Type Check Error!

    # Expected error:
    # error: Incompatible return value type (got "str", expected "int")


    def process(callback: Callable[[int], int]):
        pass

    process(lamdef(x):
        return "oops"
    )

    # Expected error:
    # error: Argument 1 to "process" has incompatible type "Callable[[Any], str]"; expected "Callable[[int], int]"


Performance Challenge in Lexer
------------------------------

Similar to [f-strings](https://peps.python.org/pep-0701/), the proposed lamdef introduces a Grammatical Inversion (INDENT/DEDENT tokens in an expression context) that disrupts the standard linear parsing flow of Python which requires specialized token handling for performance reasons.


Rationale
=========

Off-side rule
-------------

This design follows the Off-side Rule and relies on the native tokenization stream to resolve boundaries.

The syntactic delimiter belonging to the outer scope (such as `]`, `}`, `)`, `,`, or `:`) must appear at the outer indentation level to trigger the Off-side Rule, forcing the lexer to emit the DEDENT token that acts as the explicit terminator for the function body.

::

    [                 # Level 0
        lamdef(x):    # Level 4: INDENT (Function Starts)
            return x  # Level 8
    ,                 # Level 0: Triggers DEDENT (Function Ends)
    ]

    [                     # Level 0
        lamdef(x):        # Level 4: INDENT (Function Starts)
                return x  # Level 12
    ,                     # Level 0: Triggers DEDENT (Function Ends)
    ]

    [                     # Level 0
            lamdef(x):    # Level 8: INDENT (Function Starts)
                return x  # Level 12
    ,                     # Level 0: Triggers DEDENT (Function Ends)
    ]

    [lamdef(x):
        return x]  # Level 4: SyntaxError: DEDENT is not triggered before `]`

    [                 # Level 0: Outer indentation
        lamdef(x):    # Level 4
            return x  # Level 8
        ,             # Level 4: IndentationError: `,` must be at the outer indentation level (level 0)
    ]

Strict dedentation allows the parser to correctly identify trailing commas within the body as tuple constructors, rather than outer delimiters.

::

    f = lamdef(x): # Level 0: INDENT (Function Starts)
        return 1,  # Level 4: Returns a single-element tuple: (1,)
    f(1)           # Level 0: Off-side triggers DEDENT (Function Ends)


    [
        lamdef(x):
            return 1,  # Level 4: Returns a single-element tuple: (1,)
    ,                  # Level 0: Off-side triggers DEDENT (Function Ends)
    ]


Prior Art
---------

The syntactic requirement for delimiters to reside at the outer indentation level is a standard pattern in indentation-sensitive languages:

1. **Haskell & Elm**: In multi-line lists (e.g., do blocks inside a list), layout rules dictate that list delimiters must be aligned with the list elements or start a new line at the parent indentation level. This avoids ambiguity between the block's internal logic and the outer list structure.

2. **YAML**: Sequence items are delimited by -, which must appear at the parent indentation level, structurally identical to the proposed placement of commas for ``lamdef``.


Implementation
==============

Please refer to the cpython fork (https://github.com/gkirchou/cpython/tree/lamdef).


Benchmark
=========

Please refer to this repo (https://github.com/note35/lamdef/tree/main/cpython/benchmark).


FAQ
===

Does strict indentation hurt readability?
-----------------------------------------

Strict indentation is the standard, proven solution to avoid ambiguity (as noted in Prior Art), and the manual formatting burden is effectively solved by modern auto-formatters. We believe strict syntax improves readability in the specific context where ``lamdef`` is intended to be used.

**Complexity Revelation**: If a ``lamdef`` block looks "ugly" inside a container, it is likely because the logic being embedded is inherently complex. Standard ``lambda`` expressions often hide this complexity, while ``lamdef`` forces this complexity to be explicit and structured. If the structure looks too deep, it serves as a natural signal to the developer that refactoring to a named function (``def``) might be a better choice.

**Opt-in Feature**: ``lamdef`` is an opt-in feature designed for "middle-ground" complexity—where a ``lambda`` is too weak, but a named ``def`` interrupts the reading flow. It does not force a style change on simple one-liners, which should continue to use ``lambda``.


Why is Single-line Lamdef currently reserved (banned)?
------------------------------------------------------

Although single-line syntax is technically possible, we chose to reserve it (raising ``SyntaxError``) in this initial proposal. This decision prevents semantic ambiguity with ``lambda`` and enforces a clear distinction: ``lamdef`` is strictly for multi-line, statement-based logic. This also avoids the confusing edge cases such as ``[lamdef(x): x,]``, see below examples::

    # Should this be a SyntaxError?
    f = lamdef(x): x
    # If the above syntax is valid, should this be None or 1?
    a(1)

    # Should this be a SyntaxError or a list of two anonymous functions.
    [lamdef(x): x, lamdef(x): x+1]

    # Should this be SyntaxError?
    # A list of one anonymous function that returns x?
    # A list of one anonymous function that returns (x,)?
    [lamdef(x): x,] 

Why not extend lambda to support type hints?
--------------------------------------------

If you desire to have something like this::

    f = lambda (x: int, y: int): x + y

PEP 3113 removes Tuple Parameter Unpacking is one of the strongest reason::

    # SyntaxError: Lambda expression parameters cannot be parenthesized
    f = lambda (x, y): x + y


And if you desire to have something like this (no space between ``lambda`` and ``(``)::

    a = lambda(x: int, y: int): x + y

This would allow lambda to have two ways (``lambda(x):`` vs ``lambda x:``) to do the same thing, which violates the Zen of Python: There should be one-- and preferably only one --obvious way to do it.

Why not extend ``def``?
-----------------------

We do not support overloading the ``def`` keyword to function as an expression. This decision is based on the fact that the Python ecosystem—including linters, IDEs, and parsers—is built upon the assumption that ``def`` is strictly a statement. Modifying this core invariant would necessitate updates across all Python parsing tools and could introduce significant, unforeseen compatibility issues.

Why not support Type Parameters?
--------------------------------

We consider omitting this initially because defining new type parameters implies creating a **reusable generic interface**, which contradicts the "ad-hoc" nature of anonymous functions. In such cases, a standard ``def`` is the correct tool. 

For example, a generic factory like this is an anti-pattern for an anonymous function::

    # If logic is complex enough to be generic, it deserves a name.
    make_list = lamdef[T](x: T) -> list[T]:
        return [x]

Conversely, standard type hints are essential::

    # Consuming an existing TypeVar.
    def process_items[T](items: list[T]):
        # Annotate directly with the existing TypeVar rather than using [T].
        return filter(lamdef(x: T) -> bool:
            return x.is_valid()
        , items)

Why not support Async/Await?
----------------------------

We consider omitting this initially because existing ``lambda`` expressions do not support ``async`` modifiers. Furthermore, the primary use cases for anonymous functions (sorting keys, data frame operations, UI callbacks) are overwhelmingly synchronous. Introducing ``async`` syntax into an expression context would significantly increase grammar complexity.

Why not support decorators?
---------------------------

Decorator is statement-oriented and relies on line-based positioning. Introducing it into an expression context disrupts readability and complicates the grammar. Since lamdef evaluates to a function object, decorators can simply be applied functionally.

::

    # Rejected (Syntactically ambiguous in expressions)
    f = @lru_cache lamdef(x):
        return x * x

    # Recommended (Functional application)
    f = lru_cache(lamdef(x):
        return x * x
    )


Copyright
=========

This document is placed in the public domain.

..
   Local Variables:
   mode: indented-text
   indent-tabs-mode: nil
   sentence-end-double-space: t
   fill-column: 70
   coding: utf-8

   End:
