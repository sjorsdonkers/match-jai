main :: () {
    // Here is an example of a sum-type / tagged union.
    // A sum-type is defined as a struct that has a tag enum followed by a union member.
    // The tag and the union need to have the same number of members and are expected to match in order 1 to 1.
    // It is recommended to use the @SumType struct annotation to make it clear that this is intentionally a sum-type.
    Fruit :: struct @SumType {
        tag:      enum  { MANGO;     PANGO;               }
        variants: union { mango: u8; pango: string = ---; }
    }
    fruit := sum_type(Fruit, .PANGO, "yo");

    // The match macro expands an switch statement on the sum-type, to a switch on it's tag enum value.
    // Additionally, it assigns the corresponding union variant to a variable `var`.
    match(#code if fruit == {
    case .MANGO; assert("0 type: u8"      == tprint("% type: %", var, type_of(var)));
    case .PANGO; assert("yo type: string" == tprint("% type: %", var, type_of(var)));
    });

    {
        // The match macro puts the code directly into the current scope. The advantage of this is that we can just use
        // variables like we normally would from the current scope. However, the macro introduces a variable _condition in this scope as well.
        // As such if we have 2 match calls in the same scope the variable _condition is going to be redefined.
        // This is a limitation of the current implementation, it's related to the if condition being ables to be a arbitrarily expensive expression that we would not want to recompute,
        // as well as us needing to use _condition both in the current scope to switch on the condition and get the variants,
        // but also on the macro side we need it to get the Type_info out of it.
        // For now, the solution is to create a new scope for additional match calls.
        in:=5;
        match(#code if fruit == {
        case .MANGO; assert("0 type: u8 5"      == tprint("% type: % %", var, type_of(var), in));
        case .PANGO; assert("yo type: string 5" == tprint("% type: % %", var, type_of(var), in));
        });
    }

    {
        // Just like it/it_index in a for loop var can also be renamed.
        // Since if my_name_for_var: fruit == { is not valid syntax, we need to use the var_name argument.
        match(#code if fruit == {
        case .MANGO;
            #assert(!#exists(var));
            #assert(#exists(my_name_for_var));
            assert("0 type: u8"      == tprint("% type: %", my_name_for_var, type_of(my_name_for_var)));

        case .PANGO;
            #assert(!#exists(var));
            #assert(#exists(my_name_for_var));
            assert("yo type: string" == tprint("% type: %", my_name_for_var, type_of(my_name_for_var)));
        }, "my_name_for_var");
    }

    {
        // Normally `var` is a copy of the variants: `var:= fruit.variants.mango;`. This mean we cannot modify fruit through var.
        // However, by passing fruit in as a pointer *fruit, var will also be a pointer to the union variant: `var:= *fruit.variants.mango`.
        match(#code if *fruit == {
        case .MANGO; var.* += 2;
        case .PANGO; var.* = "mo";
        });
    }
    assert(fruit.tag == .PANGO && fruit.variants.pango == "mo");

    {
        // We can use a default case, but it will not have access to a union variant.
        match(#code if fruit == {
        case .MANGO; print("%\n", var);
        case;
            #assert(! #exists(var));                 // Var does not exist in the default case
            fruit = .{tag=.MANGO, variants.mango=3}; // But we can always access the sum-type directly
        });
    }

    // The switch statements works the same as any other, so directives like #complete work as expected
    {
        // Uncomment to see the compiler warning
        // match(#code if #complete fruit == {
        // case .MANGO;
        // });
    }

    {
        // The condition of the if switch can be arbitrarily complex, as long as it evaluates to the sum-type.
        // The expression will be evaluated ones and stored in a variable _condition.
        orig_fruit:= Fruit.{tag=.MANGO, variants.mango=7};
        complex_proc :: (fruit: *Fruit) -> *Fruit {
            assert(global_count == 0); global_count+=1;
            return fruit;
        }
        match(#code if complex_proc(*orig_fruit) == {
        case .MANGO; var.* += 2;
        case .PANGO; var.* = "mo";
        });
        assert(orig_fruit.tag == .MANGO && orig_fruit.variants.mango == 9);
    }

    {
        // It's OK if the type is a variant to a sum-type
        My_Fruit :: #type,distinct Fruit;
        my_fruit:= My_Fruit.{tag=.PANGO, variants.pango="wooo"};
        match(#code if my_fruit == {
        case .MANGO; assert("0 type: u8"        == tprint("% type: %", var, type_of(var)));
        case .PANGO; assert("wooo type: string" == tprint("% type: %", var, type_of(var)));
        });
    }
    {
        // The names of the enum and union members can have arbitrary names. Also nested sum-types are supported.
        Food :: struct @SumType {
            tag:   enum  { NOTFRUIT;     FRUIT;               }
            foods: union { not_fruit: u8; fruit: Fruit = ---; }
        }
        food:= Food.{tag=.FRUIT, foods.fruit=.{tag=.PANGO, variants.pango="bird"}};

        // Below we demonstrate that we can nest match calls. Note that `var` in the inner match will shadow th outer `var`, just like it/it_index would in nested for loops.
        // To expose the outer var to the inner match we can use the var_name argument to rename it in either scope.
        match(#code if food == {
        case .NOTFRUIT; assert(false);
        case .FRUIT;
            match(#code if var == {
            case .MANGO; assert(false);
            case .PANGO; assert("bird type: string" == tprint("% type: %", var, type_of(var)));
            });
        });
    }
    {
        using fruit.tag;
        match(#code if fruit == {
            case MANGO; assert("3 type: u8"      == tprint("% type: %", var, type_of(var)));
            case PANGO; assert("yo type: string" == tprint("% type: %", var, type_of(var)));
        });
    }
    {
        // A bunch of invalid cases that cause compiler errors

        // In contrast to normal if switch statements match does not support procedure calls to compute the enum variant.
        // Uncomment to see the compilation error
        // match(#code if fruit == {
        //     case cast(type_of(fruit.tag), 0);
        //     case .PANGO;
        // });

        // Match only takes if switch statements
        // match(#code print("nope"));
        // match(#code if fruit == fruit then print("nope"););

        // Only case statements are allowed in the if switch statement
        // match(#code if fruit == {
        //     a:= 2;
        // });

        // Case value is not a variant of the tags enum
        // match(#code if fruit == {
        // case .NOPE;
        // });

        // Case value is not a variant of the tags enum
        // match(#code if fruit == {
        // case .NOPE;
        // });

        // The enum index of the enum value must match a union variant
        // invalid: struct @SumType {
        //     tag:      enum  { MANGO; PANGO; }
        //     variants: union { mango: u8;    }
        // }
        // match(#code if invalid == {
        //     case .PANGO;
        // });
    }
}

global_count:= 0;

#scope_file

#import,file "../module.jai";
#import "Basic";
