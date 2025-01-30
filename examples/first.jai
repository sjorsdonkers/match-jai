// Defining MyFruit type as a Sum_Type
MyFruit :: struct @SumType {
    tag:            enum  { Pineapple;     Mango;               Kiwi;                 }
    using variants: union { Pineapple: u8; Mango: string = ---; Kiwi: MyStruct = ---; }
}
MyStruct :: struct {
    a: s32;
    b: bool;
}

sum_types :: () {
    // A sum-type is like any other struct, it just has several requirements imposed on it that we can rely on.
    // We can default construct it.
    fruitsicle: MyFruit;
    assert(fruitsicle.tag == .Pineapple && fruitsicle.Pineapple == 0);

    // We can construct it as a normal struct
    fruitsicle = MyFruit.{tag=.Mango, variants.Mango="Hello"};
    assert(fruitsicle.tag == .Mango && fruitsicle.Mango == "Hello");

    // Not however that we may put the sum-type in an invalid state when the tag does not match the active union variant.
    // fruitsicle = MyFruit.{tag=.Mango, variants.Pineapple=5}; // This will compile but accessing it as a Mango will access invalid memory.

    // Instead we can use the helper procedures to prevent invalid states. To construct any sumtype we can use sum_type(Type, tag, value)
    fruitsicle = sum_type(MyFruit, .Pineapple, cast(u8)5);

    // sum_type will not compile if a value is passed that does not fit the union variant.
    // sum_type(MyFruit, .Pineapple, "Hello"); // This will not compile -> Error: Type mismatch. Type wanted: u8; type given: string.
}

sets :: () {
    // To change the value of an existing sum-type we can use set(sum_type, tag, value)
    // This will change both the tag and the value.
    fruitsicle := sum_type(MyFruit, .Pineapple, cast(u8)5);
    set(*fruitsicle, .Kiwi, MyStruct.{34, true});
    assert(fruitsicle.tag == .Kiwi && fruitsicle.Kiwi.a == 34 && fruitsicle.Kiwi.b == true);

    // If we only want to change the value we can omit the tag.
    set(*fruitsicle, MyStruct.{53, false});
    assert(fruitsicle.tag == .Kiwi && fruitsicle.Kiwi.a == 53 && fruitsicle.Kiwi.b == false);

    // set will assert if the type does not match the union variant.
    // set(*fruitsicle, "Hello"); // This will assert -> Assertion failed: string cannot be assigned to variant Kiwi
}

unwraps :: () {
    // To get the value of a sum-type we can use unwrap(sum_type, Type)
    fruitsicle := sum_type(MyFruit, .Pineapple, cast(u8)5);
    assert(unwrap(fruitsicle, u8) == 5);

    // unwrap will assert if the type does not match the union variant.
    // unwrap(fruitsicle, string); // This will assert -> Assertion failed: string cannot be returned from variant Pineapple
}

main :: () {
    sum_types();
    sets();
    unwraps();
    // union_tags();
    // default_init();
}


#import, file "../module.jai";
#import "Basic";
