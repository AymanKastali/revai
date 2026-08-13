---
name: clean-code
description: Applies the language-agnostic clean-code standard, canonical to Robert C. Martin's Clean Code — intention-revealing names, small single-purpose functions, comments that explain why, honest error handling, cohesive classes, and the four rules of simple design. Use when writing, editing, naming, refactoring, structuring, or reviewing any function, variable, type, class, file, or module, in any language.
---

# Clean code

Code is read far more often than it is written, and the reader is usually you, later, with none of
the context you hold right now. Every rule below exists to pay that reader.

The rules are language-agnostic. Where a language's idiom genuinely conflicts with one, the idiom
wins — but say which rule you are overriding and why, rather than drifting away from it silently.

## Contents

- **Clean-code rules** — 56 rules in seven groups: names, functions, comments, formatting, objects
  and data structures, error handling, classes, and the four rules of simple design. Injected every
  session, so they may already be in your context.
- **Depth** — worked bad/good pairs for the rules that get misread without one.
- **Anti-pattern scan list** — the Ch17 smells and heuristics, 55 rows coded `C` comments,
  `F` functions, `G` general, `N` names, to work down while reviewing.

<!-- HARD-RULES:START -->
## Clean-code rules (Clean Code, Robert C. Martin)

These are not aspirations. Code that violates one is not finished.

### Names — Ch2, N1–N7

1. Reveal intent — the name says what it is, why it exists, how it's used. Needing a comment to explain a name means the name is wrong.
2. Make meaningful distinctions. Noise words are banned: `Data`, `Info`, `Object`, `Manager`, `Processor`, `Helper`, `Util`. No number series (`a1`, `a2`).
3. No disinformation — never name something after what it isn't, or after a type it doesn't have.
4. Pronounceable and searchable. Name length scales with scope size: one letter is fine in a three-line block, never at module level.
5. No encodings — no type prefixes, no member prefixes, no interface prefixes.
6. No mental mapping — the reader must never hold a translation table in their head.
7. Types are nouns, functions are verb phrases, booleans are predicates.
8. One word per concept — pick `fetch` *or* `get` *or* `retrieve` and never mix them for the same act.
9. Never pun — one word must not name two different concepts.
10. Name at the right level of abstraction — say what it does, not how it's built.
11. Add meaningful context; add no gratuitous prefixes.
12. The name discloses every side effect the thing has.

### Functions — Ch3, F1–F4

13. Small. If you can extract another named function out of it, it was too big.
14. Do one thing — one level of abstraction, describable in one sentence without "and" or "or".
15. At most two levels of indentation in a function body.
16. Stepdown rule — a file reads top-down, caller above callee, each level one step lower.
17. Arguments: zero is ideal, one is fine, two needs a reason, three or more becomes a parameter object.
18. No flag or selector arguments — a boolean that picks behavior means two functions.
19. No output arguments — return a value, or mutate the receiver.
20. Command–Query Separation — a function does something *or* answers something, never both.
21. No side effect that the name does not announce.
22. Error handling is one thing — the body of a `try` becomes its own named function.
23. DRY — extract at the third occurrence. A copy-paste with renamed variables is one responsibility wearing two hats.
24. No dead functions, no dead code, no commented-out code.

### Comments — Ch4, C1–C5

25. Explain yourself in code. A comment is an admission that the code failed to speak.
26. Legitimate comments only: intent, warning of consequence, clarification of something you cannot change, legal text, public API documentation.
27. Delete on sight: restatements of the code, journals, bylines, position markers, closing-brace labels, mandated boilerplate.
28. No commented-out code, ever. Version control remembers it for you.
29. A comment sits next to what it describes and is true. An obsolete or misleading comment is worse than none.

### Formatting — Ch5

30. Files stay small and read like a newspaper — headline first, detail descending.
31. Blank lines separate concepts; adjacency implies relationship.
32. Declare variables close to their use; keep dependent functions vertically close.
33. Caller above callee.
34. Lines stay short. Never collapse a scope onto one line.
35. Team convention beats personal preference — one style per codebase.

### Objects and data structures — Ch6

36. Hide implementation — expose abstractions, not one accessor per field.
37. Objects expose behavior and hide data; data structures expose data and hold no behavior. Pick one.
38. No hybrids — half object, half data structure is the worst of both.
39. Law of Demeter — talk only to immediate collaborators. No `a.b().c().d()` train wrecks.
40. Data transfer objects stay pure data — no business rules inside.

### Error handling — Ch7

41. Signal failure through the language's error mechanism, not magic return codes.
42. Write the failure path first, then the happy path.
43. Every error carries diagnostic context — the operation and the intent, not just a type.
44. Define error types by what the **caller** must distinguish, not by what threw.
45. Wrap third-party failure modes at the boundary so they don't leak inward.
46. Never return null — return a Special Case object, an empty collection, or an error.
47. Never pass null as an argument.

### Classes and modules — Ch10

48. A class is small when measured in responsibilities, not in lines.
49. Single Responsibility — exactly one reason to change.
50. High cohesion — few fields, and most methods touch most of them.
51. Organize for change — extension over modification.
52. Depend on abstractions, not concretions.

### Four rules of simple design — Ch12

When two rules pull in opposite directions, this order decides:

53. Passes all tests.
54. No duplication.
55. Expresses intent.
56. Fewest classes and methods.
<!-- HARD-RULES:END -->

## Depth

The rules above stand on their own sentences. These are the ones that get misread without an
example. Pseudocode is deliberately language-neutral.

### Rules 13, 14, 16 — small, one thing, stepdown

Bad — one function at four levels of abstraction at once:

```text
function payEmployees(employees):
    for e in employees:
        if e.isPayday():
            gross = e.calculatePay()
            deductions = 0
            for d in e.deductions:
                if d.active:
                    deductions = deductions + d.amount
            net = max(gross - deductions, 0)
            db.save(buildPayRecord(e, gross, deductions, net))
            mailer.send(e.email, renderPayslip(e, net))
```

Good — each function does one thing, and the file steps down one level at a time:

```text
function payEmployees(employees):
    for employee in employees:
        if employee.isPayday():
            payEmployee(employee)

function payEmployee(employee):
    payment = calculatePayment(employee)
    payrollStore.save(payment)
    payslipMailer.send(employee, payment)

function calculatePayment(employee):
    return Payment(employee.calculatePay(), activeDeductions(employee))

function activeDeductions(employee):
    return sum(d.amount for d in employee.deductions if d.active)
```

Note what disappeared: the `max(..., 0)` clamp became `Payment`'s invariant, where it belongs.

### Rule 17 — argument count

Bad — eight positional arguments, and every call site is a guessing game:

```text
createReservation(name, email, roomType, checkIn, checkOut, guestCount, smoking, promoCode)
```

Good — the arguments were always one concept:

```text
createReservation(request)     # request is a ReservationRequest
```

Three or more arguments almost always means a missing type. Find it and name it.

### Rule 20 — Command–Query Separation

Bad — sets a value *and* reports whether it existed, so the call reads as a question:

```text
if setAttribute("username", "bob"):
    ...
```

Good — one function asks, the other acts:

```text
if attributeExists("username"):
    setAttribute("username", "bob")
```

### Rule 22 — error handling is one thing

Bad — the function does the work *and* handles the failure:

```text
function deletePage(id):
    try:
        page = registry.find(id)
        registry.delete(page)
        references.deleteFor(page)
        logger.info("deleted page")
    catch error:
        logger.error(error.message)
```

Good — `deletePage` handles errors, and nothing else:

```text
function deletePage(id):
    try:
        deletePageAndReferences(id)
    catch error:
        logDeletionFailure(id, error)

function deletePageAndReferences(id):
    page = registry.find(id)
    registry.delete(page)
    references.deleteFor(page)
```

### Rule 36 — hide implementation

Bad — accessors leak that fuel is measured in gallons, so every caller does the arithmetic:

```text
class Vehicle:
    fuelTankCapacityInGallons()
    gallonsOfGasoline()
```

Good — the abstraction is what callers actually want:

```text
class Vehicle:
    percentFuelRemaining()
```

### Rules 37, 38 — anti-symmetry, and no hybrids

Bad — a hybrid: public fields *and* behavior *and* persistence:

```text
class Order:
    items            # public
    customerId       # public
    total()
    save()
```

It can't be extended with new behavior like an object, and can't have new fields added freely like a
data structure. Good — pick a side:

```text
struct OrderRecord:          # data structure: all data, no behavior
    items
    customerId

class Order:                 # object: all behavior, data hidden
    private items
    total()
    addItem(item)
```

Persistence was never either one's job — it belongs in an `OrderStore`.

### Rule 39 — Law of Demeter

Bad — a train wreck that couples the caller to three types it should not know:

```text
outputPath = context.options().scratchDirectory().absolutePath()
```

Good — ask the immediate collaborator for what you actually need:

```text
outputStream = context.createScratchStream(fileName)
```

The caller wanted a place to write, not a path. Naming the real need removed the chain.

### Rule 44 — error types the caller can act on

Bad — three vendor exception types forced on every caller, none of which they can treat differently:

```text
try:
    port.open()
catch DeviceResponseException as e:  report(e)
catch SerialTimeoutException as e:   report(e)
catch VendorGMXError as e:           report(e)
```

Good — an adapter at the boundary collapses them into the one distinction the caller makes:

```text
try:
    port.open()
catch PortDeviceFailure as e:
    report(e)
```

Three catch blocks that do the same thing prove the types were wrong for this caller.

### Rule 46 — never return null

Bad — every caller pays a null check, and the one who forgets ships a crash:

```text
employees = employeeStore.findAll()
if employees is not null:
    for e in employees:
        total = total + e.pay
```

Good — return an empty collection:

```text
for employee in employeeStore.findAll():
    total = total + employee.pay
```

When a single object is genuinely absent, return a Special Case object with neutral behavior, or an
error. Never null.

### Rules 49, 50 — single responsibility, cohesion

Bad — the name `Manager` is the tell; there are six reasons to change this class:

```text
class UserManager:
    validateEmail()
    hashPassword()
    saveToDatabase()
    sendWelcomeEmail()
    renderProfileHtml()
    exportToCsv()
```

Good — six responsibilities, each with its own cohesive home:

```text
class EmailAddress:      validate()          # a value that guards its own invariant
class PasswordHasher:    hash(), verify()
class UserStore:         save(), findById()
class WelcomeMailer:     send(user)
class ProfileView:       render(user)
class UserCsvExport:     write(users)
```

Cohesion test: if you can split a class's fields into two groups, where each group's methods only
touch their own group, it is two classes.

## Anti-pattern scan list — Ch17 smells and heuristics

A scan list, not rules. Work down it when reviewing.

| Code | Smell |
| --- | --- |
| C1 | Comment holds information that belongs elsewhere |
| C2 | Obsolete comment |
| C3 | Redundant comment — restates the code |
| C4 | Poorly written comment: rambling, imprecise, misspelled |
| C5 | Commented-out code |
| F1 | Too many arguments |
| F2 | Output arguments |
| F3 | Flag arguments |
| F4 | Dead function — nothing calls it |
| G1 | More than one language in one file |
| G2 | Obvious behavior left unimplemented |
| G3 | Incorrect behavior at the boundaries — off-by-one, empty, null, max |
| G4 | Overridden safeties — disabled warnings, skipped tests |
| G5 | Duplication — the most important smell in the list |
| G6 | Code at the wrong level of abstraction |
| G7 | Base class depending on its derivatives |
| G8 | Too much information — a fat interface with a wide public surface |
| G9 | Dead code — unreachable branches, conditions that can't be true |
| G10 | Vertical separation — a variable declared far from its use |
| G11 | Inconsistency — the same thing done two different ways |
| G12 | Clutter — unused variables, empty constructors, pointless declarations |
| G13 | Artificial coupling — unrelated things bound together |
| G14 | Feature envy — a method more interested in another class's data than its own |
| G15 | Selector arguments |
| G16 | Obscured intent — dense expressions, magic strings, cryptic chains |
| G17 | Misplaced responsibility — code not where the reader would look for it |
| G18 | Inappropriate static — a static that should have been polymorphic |
| G19 | Missing explanatory variable — name the intermediate result |
| G20 | Function name doesn't say what the function does |
| G21 | Code written without understanding the algorithm |
| G22 | Logical dependency not made physical — an assumption instead of a query |
| G23 | `if/else` or `switch` where polymorphism belongs |
| G24 | Standard convention not followed |
| G25 | Magic number instead of a named constant |
| G26 | Imprecision — a float for money, a guess instead of a lock |
| G27 | Convention where structure would enforce it |
| G28 | Unencapsulated conditional — name the predicate |
| G29 | Negative conditional where a positive one reads better |
| G30 | Function does more than one thing |
| G31 | Hidden temporal coupling — order matters but nothing enforces it |
| G32 | Arbitrary structure — organized for no stated reason |
| G33 | Unencapsulated boundary condition |
| G34 | Function descends more than one level of abstraction |
| G35 | Configurable data not kept at a high level |
| G36 | Transitive navigation — see rule 39 |
| N1 | Undescriptive name |
| N2 | Name at the wrong level of abstraction |
| N3 | Standard nomenclature not used where it applies |
| N4 | Ambiguous name |
| N5 | Short name in a long scope, or a long name in a tiny one |
| N6 | Encoded name |
| N7 | Name doesn't describe the side effect |
