---
title: Reaching Definitions
pubDate: 2025-07-22
---

Reaching definitions is a data-flow analysis technique used in compilers to determine which line could have assigned the value of a variable used at a specific point. As we all know a *definition* of an variable consists of a statement that assigns a value to the variable like so:
$$
X = 42
$$
If there is a path from the definition to a point in the program without another redefinition of the variable in between we say that this *definition **reaches** to a point in the program*. If we now assume that we have a more "complex" program like the following:
```
x = 1
y = x + 1
x = 2
z = x + 1
```

The compiler will have to keep track of where each variable was defined and what value it was assigned to last. This is where our *reaching definitions analysis* comes into play since it helps us find out:

1. Where an variable was last assigned
2. If there are multiple assignments that could have happened before this point
3. Which of the given variable assignments are still valid

We may do this by keeping track of the current statements, the active definitions, the use resolution and the updates we do. We can imagine the program now in a table like so:

| Line | Statement   | Active Definitions | Use Resolution | Update |
| ---- | ----------- | ------------------ | -------------- | ------ |
| 1    | $x = 1$     |                    |                |        |
| 2    | $y = x + 1$ |                    |                |        |
| 3    | $x = 2$     |                    |                |        |
| 4    | $z = x + 1$ |                    |                |        |

In the first row, since we only define a variable $x$, we may only update the "Update" column, this column will consist of either "Add" and "Kill" keywords, the first used to keep track of the newly defined values and the latter to keep track of the values that are now invalid.

| Line | Statement   | Active Definitions | Use Resolution | Update |
| ---- | ----------- | ------------------ | -------------- | ------ |
| 1    | $x = 1$     |                    |                | Add x1 |
| 2    | $y = x + 1$ |                    |                |        |
| 3    | $x = 2$     |                    |                |        |
| 4    | $z = x + 1$ |                    |                |        |

In the next line we have a statement where we define a new variable called $y$ and its value is a expression where $x$ **reaches** $y$, thus we need to update our columns accordingly by first getting stuff we already know straight. So far we know that:
- we have an **active definition** of $x1$ 
- $x$ references the first assignment of itself (thus the name $x1$)
- we are creating an new definition called $y$
  
With this information we can update the table accordingly:

| Line | Statement   | Active Definitions | Use Resolution | Update   |
| ---- | ----------- | ------------------ | -------------- | -------- |
| 1    | $x = 1$     |                    |                | Add `x1` |
| 2    | $y = x + 1$ | `[x1]`             | $x$ = `x1`     | Add `y1` |
| 3    | $x = 2$     |                    |                |          |
| 4    | $z = x + 1$ |                    |                |          |

Moving on to the third line, the statement reassigns our variable $x$ effectively making another version of itself, thus the old version is **killed** and we stop tracking its old value. If we continue this process now we end up with something like this:

| Line | Statement   | Active Definitions  | Use Resolution | Update              |
| ---- | ----------- | ------------------- | -------------- | ------------------- |
| 1    | $x = 1$     |                     |                | Add `x1`            |
| 2    | $y = x + 1$ | `[x1]`              | $x$ = `x1`     | Add `y1`            |
| 3    | $x = 2$     | `[x1, y1]`          |                | Kill `x1`; Add `x2` |
| 4    | $z = x + 1$ | `[x2, y1]`          | $x$ = `x2`     | Add `z1`            |

Once the compiler has done this it can decide if it should *eliminate* the variable or *rewrite* it so the variables name gets replaced with the actual assigned value of the variable. To now achieve something like this in Python we would first define our "code" as an list of strings:

```python
code = [
	"x = 1",
	"y = x + 1",
	"x = 2",
	"z = x + 1"
]
```

Then we add some global variables:
```python
defined_vars = []
var_versions = []
definitions = []
version_counter = {}
```

And then we jump into our main logic:
```python
for i in range(len(code)):
	used = []
	
	# 1. split code into variable name and expression
    var_name, expression = map(str.strip, code[i].split('='))
	
	# 2. tokenize expression
    tokens = expression.split()
	
	# 3. check if there is a variable used in the expression & print it
    for token in tokens:
        if token in defined_vars:
            idx = defined_vars.index(token)
            used.append(var_versions[idx])
    if used:
        print(f"line {i+1} uses {used}")
	
	# 4. keep track of each variables version
    if var_name not in version_counter:
        version_counter[var_name] = 1
    else:
        version_counter[var_name] += 1
	
	# 5. construct variable name with version
    new_var_name = var_name + str(version_counter[var_name])
	
	# 6. add or modify variable to var_versions list
    if var_name in defined_vars:
        idx = defined_vars.index(var_name)
        var_versions[idx] = new_var_name
    else:
        defined_vars.append(var_name)
        var_versions.append(new_var_name)
	
	# 7. keep track of assignments
    definitions.append((new_var_name, expression))

# profit ???
for i in range(len(definitions)):
    print(f"{i}) {definitions[i][0]} = {definitions[i][1]}")

```

Feel free to call me out if I am wrong about anything, this topic has confused me for a while. :)
