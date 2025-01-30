// Construct a Sum_Type with a specific variant and value.
// fruitsicle := sum_type(MyFruit, .Pineapple, cast(u8)5);
sum_type :: ($ST: Type, $tag: type_of(ST.tag), value: $V) -> ST {
    sum :ST= ---;
    set(*sum, tag, value);
    return sum;
}

// Requires the tag member to be named tag
// set(*fruit, .pango, "Hello");
set :: (st: *$ST, $tag: type_of(ST.tag), value: $V) {
    st.tag = tag;
    #insert -> string {
        valid, tag_member, union_member, tag_info, union_info := is_valid_sumtype(type_info(ST));

        found, index := array_find(tag_info.values, xx tag);  assert(found);
        variant_name := union_info.members[index].name;
        if union_member.name { return tprint("st.%.% = value;", union_member.name, variant_name); }
        else {                 return tprint("st.% = value;", variant_name); }
    }
}

// V needs to match the union variant type exactly
set :: (st: *$ST, value: $V) {
    #insert -> string {
        valid, tag_member, union_member, tag_info, union_info := is_valid_sumtype(type_info(ST));

        builder: String_Builder;
        print_to_builder(*builder, "match(#code if st == {\n");
        for tag_info.names {
            if type_info(V) == xx union_info.members[it_index].type {
                print_to_builder(*builder, "case .%; var.* = value; return;\n", it);
            }
        }
        print_to_builder(*builder, "});\n");
        return builder_to_string(*builder);
    }
    assert(false, "% cannot be assigned to variant %", V, st.*); // TODO `of type x`
}

// sumtype and set without tag arg

// unwrap(u, T): Returns a pointer to the value stored in the variant of 'u'.
// Crashes if 'u' is not of type 'T'. (TODO)
// mango := unwrap(fruitsicle, MyFruit.Mango);
unwrap :: (st: $ST, $Return: Type) -> Return { // TODO check can we return original type?
    // if Return is Any make sure ST is a pointer

    #insert -> string {
        valid, tag_member, union_member, tag_info, union_info := is_valid_sumtype(ST);

        builder: String_Builder;
        print_to_builder(*builder, "match(#code if st == {\n");
        for tag_info.names {
            if type_info(Return) == xx union_info.members[it_index].type {
                print_to_builder(*builder, "case .%; return var;\n", it);
            }
        }
        print_to_builder(*builder, "});\n");
        return builder_to_string(*builder);
    }
    assert(false, "% cannot be returned from variant %", Return, st); // TODO `of type x`
    ret: Return;
    return ret;
}

union_tag :: ($U: Type) -> Type #expand #compile_time {
    info :*Type_Info_Struct: type_info(U);
    #assert(info.type == .STRUCT && info.textual_flags & .UNION);

    Tag :: enum {
        #insert -> string {
            builder: String_Builder;
            for info.members {
                assert(it.name.count != 0, "Anonymous unions variants are not allowed at index: %", it_index);
                print_to_builder(*builder, "% :: %;\n", it.name, it_index);

                // Currently it is required for the union to default init to the first member.
                // If Type_Info_Struct_Member.enum_flags had a flag for IS_UNINITIALIZED we might use that to set the right enum variant or at least detect errors.
            }
            return builder_to_string(*builder);
        }
    }
    return Tag;
}

is_valid_sumtype :: ($type: Type) -> bool, tag_member:*Type_Info_Struct_Member=null, union_member:*Type_Info_Struct_Member=null, tag_info:*Type_Info_Enum=null, union_info:*Type_Info_Struct=null {
    ok, struct_info := base_struct_info(type_info(type)); assert(ok);
    valid, tag_member, union_member, tag_info, union_info := is_valid_sumtype(struct_info);
    return valid, tag_member, union_member, tag_info, union_info;
}
is_valid_sumtype :: (struct_info: *Type_Info_Struct) -> bool, tag_member:*Type_Info_Struct_Member=null, union_member:*Type_Info_Struct_Member=null, tag_info:*Type_Info_Enum=null, union_info:*Type_Info_Struct=null {
    if struct_info.members.count != 2                                      return false;
    tag_member, union_member:= *struct_info.members[0], *struct_info.members[1];
    if tag_member.type.type != .ENUM || union_member.type.type != .STRUCT  return false;
    tag_info :*Type_Info_Enum= xx tag_member.type;
    union_info :*Type_Info_Struct= xx union_member.type;
    if union_info.textual_flags & .UNION == 0                              return false;
    if tag_info.values.count != union_info.members.count                   return false;
    return true, tag_member, union_member, tag_info, union_info;
}

base_struct_info :: (info: *Type_Info) -> ok:=false, struct_info:*Type_Info_Struct=null {
    if info.type == {
    case .POINTER;
        pointer_info :*Type_Info_Pointer= xx info;
        ok, struct_info:= base_struct_info(pointer_info.pointer_to); // TODO may go down only 1 pointer level in total
        return ok, struct_info;
    case .VARIANT;
        variant_info :*Type_Info_Variant= xx info;
        ok, struct_info:= base_struct_info(variant_info.variant_of);
        return ok, struct_info;
    case .STRUCT; return true, xx info;
    }
    return;
}

#scope_file
#import "Basic";
#import "Compiler";
