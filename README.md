# match-jai

```odin
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
