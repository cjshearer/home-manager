{ lib }:

{
  toHyprconf = { attrs, indentLevel ? 0, importantPrefixes ? [ "$" ], }:
    let
      inherit (lib)
        all concatMapStringsSep concatStrings concatStringsSep filterAttrs foldl
        generators hasPrefix isAttrs isList mapAttrsToList replicate;

      initialIndent = concatStrings (replicate indentLevel "  ");

      toHyprconf' = indent: attrs:
        let
          sections =
            filterAttrs (n: v: isAttrs v || (isList v && all isAttrs v)) attrs;

          mkSection = n: attrs:
            if lib.isList attrs then
              (concatMapStringsSep "\n" (a: mkSection n a) attrs)
            else ''
              ${indent}${n} {
              ${toHyprconf' "  ${indent}" attrs}${indent}}
            '';

          mkFields = generators.toKeyValue {
            listsAsDuplicateKeys = true;
            inherit indent;
          };

          allFields =
            filterAttrs (n: v: !(isAttrs v || (isList v && all isAttrs v)))
            attrs;

          isImportantField = n: _:
            foldl (acc: prev: if hasPrefix prev n then true else acc) false
            importantPrefixes;

          importantFields = filterAttrs isImportantField allFields;

          fields = builtins.removeAttrs allFields
            (mapAttrsToList (n: _: n) importantFields);
        in mkFields importantFields
        + concatStringsSep "\n" (mapAttrsToList mkSection sections)
        + mkFields fields;
    in toHyprconf' initialIndent attrs;

  toKDL = { }:
    let
      inherit (lib) concatStringsSep splitString mapAttrsToList any;
      inherit (builtins) typeOf replaceStrings elem;

      # ListOf String -> String
      indentStrings = let
        # Although the input of this function is a list of strings,
        # the strings themselves *will* contain newlines, so you need
        # to normalize the list by joining and resplitting them.
        unlines = lib.splitString "\n";
        lines = lib.concatStringsSep "\n";
        indentAll = lines: concatStringsSep "\n" (map (x: "	" + x) lines);
      in stringsWithNewlines: indentAll (unlines (lines stringsWithNewlines));

      # String -> String
      sanitizeString = replaceStrings [ "\n" ''"'' ] [ "\\n" ''\"'' ];

      # OneOf [Int Float String Bool Null] -> String
      literalValueToString = element:
        lib.throwIfNot
        (elem (typeOf element) [ "int" "float" "string" "bool" "null" ])
        "Cannot convert value of type ${typeOf element} to KDL literal."
        (if typeOf element == "null" then
          "null"
        else if element == false then
          "false"
        else if element == true then
          "true"
        else if typeOf element == "string" then
          ''"${sanitizeString element}"''
        else
          toString element);

      # Attrset Conversion
      # String -> AttrsOf Anything -> String
      convertAttrsToKDL = name: attrs:
        let
          optArgsString = lib.optionalString (attrs ? "_args")
            (lib.pipe attrs._args [
              (map literalValueToString)
              (lib.concatStringsSep " ")
              (s: s + " ")
            ]);

          optPropsString = lib.optionalString (attrs ? "_props")
            (lib.pipe attrs._props [
              (lib.mapAttrsToList
                (name: value: "${name}=${literalValueToString value}"))
              (lib.concatStringsSep " ")
              (s: s + " ")
            ]);

          children =
            lib.filterAttrs (name: _: !(elem name [ "_args" "_props" ])) attrs;
        in ''
          ${name} ${optArgsString}${optPropsString}{
          ${indentStrings (mapAttrsToList convertAttributeToKDL children)}
          }'';

      # List Conversion
      # String -> ListOf (OneOf [Int Float String Bool Null])  -> String
      convertListOfFlatAttrsToKDL = name: list:
        let flatElements = map literalValueToString list;
        in "${name} ${concatStringsSep " " flatElements}";

      # String -> ListOf Anything -> String
      convertListOfNonFlatAttrsToKDL = name: list: ''
        ${name} {
        ${indentStrings (map (x: convertAttributeToKDL "-" x) list)}
        }'';

      # String -> ListOf Anything  -> String
      convertListToKDL = name: list:
        let elementsAreFlat = !any (el: elem (typeOf el) [ "list" "set" ]) list;
        in if elementsAreFlat then
          convertListOfFlatAttrsToKDL name list
        else
          convertListOfNonFlatAttrsToKDL name list;

      # Combined Conversion
      # String -> Anything  -> String
      convertAttributeToKDL = name: value:
        let vType = typeOf value;
        in if elem vType [ "int" "float" "bool" "null" "string" ] then
          "${name} ${literalValueToString value}"
        else if vType == "set" then
          convertAttrsToKDL name value
        else if vType == "list" then
          convertListToKDL name value
        else
          throw ''
            Cannot convert type `(${typeOf value})` to KDL:
              ${name} = ${toString value}
          '';
    in attrs: ''
      ${concatStringsSep "\n" (mapAttrsToList convertAttributeToKDL attrs)}
    '';

  # To avoid collision with keys that module authors may need to serialize, the
  # keys for encoded values can be customized. The grammar for RON can be found
  # at: https://github.com/ron-rs/ron/blob/master/docs/grammar.md
  toRON = { newline ? "\n", tab ? "    ", encodingKeys ? {
    prefix = "_prefix";
    suffix = "_suffix";
    type = "_type";
    value = "_value";
  } }:
    let
      inherit (builtins) elem typeOf isAttrs hasAttr any;
      inherit (lib) boolToString concatStringsSep mapAttrsToList optionalString;
      inherit (lib.strings) floatToString;

      delimiter.bool."" = {};

      delimiter.float.f32.close = "f32";
      delimiter.float.f64.close = "f64";
      delimiter.float."" = {};

      delimiter.int.i8.close = "i8";
      delimiter.int.u8.close = "u8";
      delimiter.int.i16.close = "i16";
      delimiter.int.u16.close = "u16";
      delimiter.int.i32.close = "i32";
      delimiter.int.u32.close = "u32";
      delimiter.int.i64.close = "i64";
      delimiter.int.u64.close = "u64";
      delimiter.int.i128.close = "i128";
      delimiter.int.u128.close = "u128";
      delimiter.int.isize.close = "isize";
      delimiter.int.usize.close = "usize";
      delimiter.int."" = { };

      delimiter.list.tuple.open = "(";
      delimiter.list.tuple.close = ")";
      delimiter.list."".open = "[";
      delimiter.list."".close = "]";

      delimiter.null."" = {};

      delimiter.path."".open = ''"'';
      delimiter.path."".close = ''"'';

      delimiter.string.octal.open = "0o";
      delimiter.string.hex.open = "0x";
      delimiter.string.char.open = "'";
      delimiter.string.char.close = "'";
      delimiter.string.byte.open = "b'";
      delimiter.string.byte.close = "'";
      delimiter.string.binary.open = "0b";
      delimiter.string."".open = ''"'';
      delimiter.string."".close = ''"'';

      delimiter.set.struct.open = "(";
      delimiter.set.struct.close = ")";
      delimiter.set.enum.open = "(";
      delimiter.set.enum.close = ")";
      delimiter.set."".open = "{";
      delimiter.set."".close = "}";

      isEncoded = value:
        isAttrs value && any (attr: hasAttr attr value)
        (mapAttrsToList (_: v: v) encodingKeys);

      serializePrimitive = indent: value:
        {
          int = toString value;
          float = floatToString value;
          bool = boolToString value;
          string = value;
          path = toString value;
          null = "";
          set = lib.pipe value [
            (mapAttrsToList (k: v:
              "${indent + tab}${k}: ${serialize { indent = indent + tab; } v}"))
            (concatStringsSep ("," + newline))
            (v:
              optionalString (v != "") newline + v
              + optionalString (v != "") (newline + indent))
          ];
          list = lib.pipe value [
            (map
              (v: "${indent + tab}${serialize { indent = indent + tab; } v}"))
            (concatStringsSep ("," + newline))
            (v:
              optionalString (v != "") newline + v
              + optionalString (v != "") (newline + indent))
          ];
        }.${typeOf value} or (throw
          ''Can't serialize "${typeOf value}" to RON'');

      serialize = { indent ? "" }:
        input:
        let
          valueType = typeOf (input.${encodingKeys.value} or input);
          explicitType = input.${encodingKeys.type} or "";
          value = if isEncoded input then
            input.${encodingKeys.value} or null
          else
            input;
          serializedValue = if isEncoded value then
            if value == null then "" else serialize { inherit indent; } value
          else
            serializePrimitive indent value;
          prefix = input.${encodingKeys.prefix} or "";
          suffix = input.${encodingKeys.suffix} or "";
          delimiters = delimiter.${valueType}.${explicitType} or (throw "cannot convert ${valueType} to ${explicitType}" (builtins.trace value ""));
        in prefix + delimiters.open or "" + serializedValue + delimiters.close or ""
        + suffix;
    in serialize { };

  toSCFG = { }:
    let
      inherit (lib) concatStringsSep mapAttrsToList any;
      inherit (builtins) typeOf replaceStrings elem;

      # ListOf String -> String
      indentStrings = let
        # Although the input of this function is a list of strings,
        # the strings themselves *will* contain newlines, so you need
        # to normalize the list by joining and resplitting them.
        unlines = lib.splitString "\n";
        lines = lib.concatStringsSep "\n";
        indentAll = lines: concatStringsSep "\n" (map (x: "	" + x) lines);
      in stringsWithNewlines: indentAll (unlines (lines stringsWithNewlines));

      # String -> Bool
      specialChars = s:
        any (char: elem char (reserved ++ [ " " "'" "{" "}" ]))
        (lib.stringToCharacters s);

      # String -> String
      sanitizeString =
        replaceStrings reserved [ ''\"'' "\\\\" "\\r" "\\n" "\\t" ];

      reserved = [ ''"'' "\\" "\r" "\n" "	" ];

      # OneOf [Int Float String Bool] -> String
      literalValueToString = element:
        lib.throwIfNot (elem (typeOf element) [ "int" "float" "string" "bool" ])
        "Cannot convert value of type ${typeOf element} to SCFG literal."
        (if element == false then
          "false"
        else if element == true then
          "true"
        else if typeOf element == "string" then
          if element == "" || specialChars element then
            ''"${sanitizeString element}"''
          else
            element
        else
          toString element);

      # Bool -> ListOf (OneOf [Int Float String Bool]) -> String
      toOptParamsString = cond: list:
        lib.optionalString (cond) (lib.pipe list [
          (map literalValueToString)
          (concatStringsSep " ")
          (s: " " + s)
        ]);

      # Attrset Conversion
      # String -> AttrsOf Anything -> String
      convertAttrsToSCFG = name: attrs:
        let
          optParamsString = toOptParamsString (attrs ? "_params") attrs._params;
        in ''
          ${name}${optParamsString} {
          ${indentStrings (convertToAttrsSCFG' attrs)}
          }'';

      # Attrset Conversion
      # AttrsOf Anything -> ListOf String
      convertToAttrsSCFG' = attrs:
        mapAttrsToList convertAttributeToSCFG
        (lib.filterAttrs (name: val: !isNull val && name != "_params") attrs);

      # List Conversion
      # String -> ListOf (OneOf [Int Float String Bool]) -> String
      convertListOfFlatAttrsToSCFG = name: list:
        let optParamsString = toOptParamsString (list != [ ]) list;
        in "${name}${optParamsString}";

      # Combined Conversion
      # String -> Anything  -> String
      convertAttributeToSCFG = name: value:
        lib.throwIf (name == "") "Directive must not be empty"
        (let vType = typeOf value;
        in if elem vType [ "int" "float" "bool" "string" ] then
          "${name} ${literalValueToString value}"
        else if vType == "set" then
          convertAttrsToSCFG name value
        else if vType == "list" then
          convertListOfFlatAttrsToSCFG name value
        else
          throw ''
            Cannot convert type `(${typeOf value})` to SCFG:
              ${name} = ${toString value}
          '');
    in attrs:
    lib.optionalString (attrs != { }) ''
      ${concatStringsSep "\n" (convertToAttrsSCFG' attrs)}
    '';
}
