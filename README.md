# match-jai

`match(..)` is a macro that enable you to if switch on enum union pair in a struct (sum-type).
A sum-type is here defined as a struct that has a tag enum and a union with a @UnionTag note to indicate the tag member name. The tag and union are required to have the same number of variants.
Match expands a the switch statement, such that the acive union variant is accessible in the case block, by default named `var`.

```jai
Fruit :: struct {
    tag:      enum  { MANGO;     PANGO;               }
    variants: union { mango: u8; pango: string = ---; } @UnionTag:tag
}
fruit: Fruit;

match(#code if fruit == {
case .MANGO; print("Mango % of type: %\n", var, type_of(var));
case .PANGO; print("Pango % of type: %\n", var, type_of(var));
});
```

## Testing
`jai ./tests.jai`  
- The module is tested by compiling and running the examples. The command above does that for all examples.
