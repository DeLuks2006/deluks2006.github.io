---
title: Liveness Analysis
pubDate: 2025-07-23
---

Live Variable Analysis, also known as *Liveness Analysis*, is a data-flow analysis technique used by compilers to identify *dead code*, specifically, variable assignments whose values are never used. To understand this analysis, it's essential to define the concepts of **live variables** and **live ranges**. 

A *live variable* is a variable that holds a value which may be used in the future before it is overwritten. The *live range* of a variable is the region of code where the variable remains live.

Let us take the following code for example:

```
a = 3
b = 5
c = add(a, b)
```

Here, $a$ and $b$ are live from lines 1 till 3 because their values are used in the call to the function $add()$. However, the variable $c$ is dead immediately after line 3 because its value is not used anywhere in our example. Now if we assume that our $add()$ function does not have any side effects, the compiler could eliminate the third line completely from the final compiled code.

To perform liveness analysis programatically, the compiler walks our control flow graph *backwards*, while maintaining a set of variables whose values may be needed in the code. This is process is also called "Backwards May" Analysis and it allows the compiler to find out which variable assignments are necessary and which are not.

Below is an simple example of this algorithm made in Python:

```python
def dead_code(code):
	used = []
	assigned = []
	
	# 1. Reverse May Analysis
	# for each line in the code (in reverse...)
	for line in reversed(code):
		if '=' in line: # if we wind an assignment
			# split them thangs & append to list of assigned vars
			var, expression = map(str.strip, line.split('=', 1))
			assigned.append(var)
			
			expression = expression.replace('(', ' ').replace(')', ' ').replace(',', ' ').split()
			
			# if a token in the expression is not present in used, add it there
			for token in expression:
				if token.isidentifier() and token not in used:
					used.append(token)
	
	# find dead code with our data we found above
	dead = []
	for var in assigned:
		if var not in used:
			dead.append(var)
	
	return dead

code = [
	"a = 3",
	"b = 5",
	"c = add(a, b)"
]

print("out of the following code:")

for l in code:
    print(l)

print(f"\nvariables {dead_code(code)} are dead")
```

Anyhow as we saw the algorithm is quite a simple but effective one which helps the compiler find useless code it could freely remove. I hope that enjoyed this post and, as always, this short post is just meant for me to learn more about these topics in a short period of time so please, if you find anything wrong, feel free to get in contact with me. :)

# References
- [Wikipedia](https://en.wikipedia.org/wiki/Live-variable_analysis)
- [GeeksForGeeks](https://www.geeksforgeeks.org/compiler-design/liveliness-analysis-in-compiler-design/)
