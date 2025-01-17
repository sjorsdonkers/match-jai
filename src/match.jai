// Match expands a switch statement on a sum-type struct, such that the union variant is accessible in the case block.
// A sum-type is defined as a struct that has a tag enum and a union with a @UnionTag note to indicate the tag member name.
// The tag and union are required to have the same number of variants. Only 1 tagged union pair per struct is supported.
// The union may not be hidden within a nested using-ed struct.
//
// Example sum-type:
//
// Fruit :: struct {
//     tag:      enum  { MANGO;     PANGO;               }
//     variants: union { mango: u8; pango: string = ---; } @UnionTag:tag
// }
//
// Input code:
// if fruit == {
// case .MANGO; print("Mango %\n", var);
// case .PANGO; print("Pango %\n", var);
// }

// Expands to a switch statement on the tag of the sum-type and assigns the union variant to a var:
// _condition:= fruit;
// if _condition.tag == {
// case .MANGO;
//     var:= _condition.variants.mango;
//     print("Mango %\n", var);
// case .PANGO;
//     var:= _condition.variants.pango;
//     print("Pango %\n", var);
// }
//
// var_name sets the name for the generated variable. Just like it/it_index are in a for loop.
// Ideally you could change it with official syntax like: `if my_var: fruit == {`
match :: (code:Code, var_name:="var", call:=#caller_code) #expand {
    // Compute the original condition expression here once, to prevent recomputation and to enable us to get the type as well as the values out
    `_condition:= #insert,scope(call) -> Code {
        root := compiler_get_nodes(code);

        if root.kind != .IF { compiler_report("The code passed to match must be an if switch statement.", make_location(root)); }
        if_root :*Code_If= xx root;
        if (if_root.if_flags & .IS_SWITCH_STATEMENT) == 0 { compiler_report("The if statement in match needs to be a switch: if condition == {.", make_location(if_root)); }

        return compiler_get_code(if_root.condition);
    };

    // Note: currently it is not possible for the union not to have a name as a name is required to put a tag on it.
    union_name, tag_name :: #run get_union_info(type_of(_condition));
    #insert #run tprint("enum_info  :: type_info(type_of(_condition.%));", tag_name);
    #insert #run tprint("union_info :: type_info(type_of(_condition.%));", union_name);

    #insert,scope(call) -> Code {
        if_root :*Code_If= xx compiler_get_nodes(code);

        // Change the condition to be the tag enum value of the original condition
        template :: #code _condition.tag_name;
        new_condition, tag_nodes:= compiler_get_nodes(template);
        for tag_nodes if it.kind == .IDENT {
            ident :*Code_Ident= xx it;
            if ident.name == "tag_name"  ident.name = tag_name;
        }
        if_root.condition = new_condition;

        // Insert `var:= *condition.union.variant;` at the start of each case block
        for if_root.then_block.statements {
            code_case :*Code_Case= xx it;
            if code_case.condition == null continue; // Default case

            // Get the name of the enum variant from the case condition.
            // TODO this may be a procedure that we need to resolve, CASE conditions need to resolve at compile time.
            // case condition expression could be complex, dot operators are to be expected
            // Recursively get till we are at the last @speed we we don't need to collect or recurse into all, we just need the last one
            nodes: [..] *Code_Node;
            get_recursive_nodes_breadth_first(code_case.condition, *nodes);
            assert(nodes.count > 0, "match(..) implementation issue, the default case should not be processed");
            if peek(nodes).kind != .IDENT { compiler_report("Case condition must be an explicit enum variant identifier.", make_location(code_case.condition)); }
            enum_variant :*Code_Ident= xx peek(nodes);

            // Use index to get name of union variant and assign the value to `var`
            found, index := array_find(enum_info.names, enum_variant.name);
            if !found { compiler_report("The case value is not a variant of the tags enum", make_location(code_case.condition)); }
            if index >= union_info.members.count { compiler_report("The tag's variant has no related index in the union", make_location(code_case.condition)); }
            unions_variant_name := union_info.members[index].name;

            make_var_declaration :: (union_name: string, variant_name: string, variable_name: string, by_pointer: bool) -> *Code_Declaration {
                template:= ifx union_name
                    then ifx by_pointer
                        then #code variable_name:= *_condition.union_name.variant_name
                        else #code variable_name:=  _condition.union_name.variant_name
                    else ifx by_pointer
                        then #code variable_name:= *_condition.variant_name
                        else #code variable_name:=  _condition.variant_name;

                root, decl_nodes:= compiler_get_nodes(template);
                decl :*Code_Declaration= xx root;

                // Rename variables in the declaration
                decl.name = variable_name;
                for decl_nodes if it.kind == .IDENT {
                    ident :*Code_Ident= xx it;
                    if ident.name == "union_name"    ident.name = union_name;
                    if ident.name == "variant_name"  ident.name = variant_name;
                }
                return decl;
            }

            // Prepend the new statement to the existing statements of the current case block
            new_statements : [..] *Code_Node;
            condition_by_pointer := type_info(type_of(_condition)).type == .POINTER;
            array_add(*new_statements, make_var_declaration(union_name, unions_variant_name, var_name, condition_by_pointer));
            array_add(*new_statements, ..code_case.then_block.statements);
            code_case.then_block.statements = new_statements;
        }
        return compiler_get_code(if_root);
    }
}

#scope_file

base_struct_info :: (info: *Type_Info) -> ok:=false, struct_info:*Type_Info_Struct=null {
    if info.type == {
    case .POINTER;
        pointer_info :*Type_Info_Pointer= xx info;
        ok, struct_info:= base_struct_info(pointer_info.pointer_to);
        return ok, struct_info;
    case .VARIANT;
        variant_info :*Type_Info_Variant= xx info;
        ok, struct_info:= base_struct_info(variant_info.variant_of);
        return ok, struct_info;
    case .STRUCT; return true, xx info;
    }
    return;
}

// The union must be directly within the sum-types struct. We do not recursively search for the union in nested using-ed structs.
get_union_info :: ($type: Type) -> union_name:="", tag_name:="" {
    ok, info:= base_struct_info(type_info(type)); assert(ok);
    for member: info.members {
        // Find union member with @UnionTag note
        if member.type.type != .STRUCT continue;
        member_info :*Type_Info_Struct= xx member.type;
        if !(member_info.textual_flags & .UNION) continue;
        tag_name: string;
        for note: member.notes if begins_with(note, "UnionTag:") { tag_name = slice(note, 9, note.count-9); break; }
        if tag_name then return member.name, tag_name;
    }
    assert(false, "No union member found in % with an @UnionTag:TAG_NAME note", info.name);
    return;
}

#import "Basic";
#import "String";
#import "Compiler";
#import "Code_Visit";
