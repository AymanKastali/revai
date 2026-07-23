# Smells & heuristics

This file adds no new rules. Every smell below is a symptom that one of the other clean-code
references was already violated somewhere in the diff — the smell is just the observable shape that
violation takes once enough code has grown around it. Use this as a fast recognition pass: spot the
symptom, name the smell precisely instead of describing it vaguely, then go apply the fix it points
to. If a smell here doesn't map to a rule you can name, it isn't pinned down yet — keep looking
before you touch the code.

## Catalog

| Smell | Symptom | Fix |
|---|---|---|
| Rigidity | One change forces edits across many unrelated files because responsibilities were never separated — nothing in this codebase can move alone. | Split by responsibility per `reference/classes-and-cohesion.md`'s cohesion rule; a class that changes for one reason doesn't drag its neighbors along. |
| Fragility | Changing code in one place breaks something in a seemingly unconnected place, because a hidden dependency or side effect linked them invisibly. | Remove the hidden coupling — apply `reference/functions.md`'s no-hidden-side-effects rule and `reference/objects-and-data-structures.md`'s encapsulation rule so a function's name is a complete promise. |
| Immobility | Code that's genuinely useful elsewhere can't be lifted out, because it's wired to collaborators it doesn't conceptually need. | Cut the accidental dependencies — apply `reference/objects-and-data-structures.md`'s Law of Demeter so the unit only talks to what it actually needs, then extract it. |
| Needless complexity | An abstraction, layer, or configuration option exists for a problem the code doesn't currently have — nobody can point to the case it protects against. | Delete it. Apply the fourth rule of simple design (`SKILL.md`): no more elements than the code needs right now, not the code it might need. |
| Needless repetition | The same business rule is written out in two or more places, and a future change to that rule has to remember every copy. | Extract the shared rule per `reference/functions.md`'s DRY-targets-knowledge rule — only if it's the same rule twice, not just similar-looking shape. |
| Opacity | Understanding what a piece of code does takes real, avoidable effort — re-reading, tracing, or asking someone — even though nothing here is inherently hard. | Rename and restructure per `reference/naming.md`'s reveal-intent rule; if a comment is doing the work a name should, that's the tell. |
| Divergent change | One class or module gets edited for many unrelated reasons over months — a new field here, a new report there, a new validation rule next week — all in the same file. | Split the class along its actual responsibilities per `reference/classes-and-cohesion.md`'s cohesion rule; each resulting piece should change for exactly one reason. |
| Shotgun surgery | A single conceptual change (rename a concept, add a field) requires hunting down and editing many different files and classes to land it. | The opposite failure of the same cohesion problem — group what changes together, per `reference/classes-and-cohesion.md`; if it always changes together, it belongs together. |
| Feature envy | A method spends more time calling another class's getters than it does using its own class's data or methods. | Move the method (or the logic) onto the class whose data it actually uses — `reference/objects-and-data-structures.md`'s tell-don't-ask rule: ask the object to do the thing instead of pulling its data out to do it yourself. |
| Inappropriate intimacy | Two classes reach into each other's private fields or internal structure directly, instead of collaborating through a small public interface. | Narrow the interface between them per `reference/objects-and-data-structures.md`'s Law of Demeter — talk to immediate collaborators only, never their internals. |
| Primitive obsession | A bare `string`, `int`, or `bool` stands in for a real domain concept (an email, a percentage, a status) with no validation or behavior attached anywhere. | Give the concept its own type — `reference/naming.md`'s name-by-role rule plus a small value type that validates itself at construction, instead of a primitive every caller must re-validate. |
| Long parameter list | A function or constructor takes so many arguments that call sites are unreadable and it's easy to pass two of the same type in the wrong order. | Group the arguments that travel together into one type, per `reference/functions.md`'s few-arguments rule (0-2 ideal, 3 is the ceiling). |
| Speculative generality | A hook, parameter, or abstract base exists for a future need someone imagined, not one the code has been asked to support yet. | Remove it now; add it when a real second case shows up. Same root as needless complexity — the fourth rule of simple design (`SKILL.md`) covers both. |
| Dead code | A function, branch, or whole file that nothing calls anymore, kept "just in case" instead of deleted. | Delete it outright — version control is the "just in case," not a commented-out or unreachable copy sitting in the source tree. |

## Checklist

- [ ] Every smell noticed in the diff is named from this table, not described in vague terms
      ("this feels messy")
- [ ] Each named smell is traced to the specific rule it violates, not just flagged and left
- [ ] Divergent change and shotgun surgery aren't confused — one is too many reasons in one place,
      the other is one reason spread across too many places
- [ ] Feature envy and inappropriate intimacy aren't confused — one is a method reaching out,
      the other is two classes reaching into each other
- [ ] Needless complexity and speculative generality aren't excused as "flexibility" — both mean
      cutting code that has no current caller or case
- [ ] The fix applied is the one the smell's row points to, not a workaround that leaves the
      underlying rule still broken
