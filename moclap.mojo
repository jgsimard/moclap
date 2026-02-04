from sys import argv
from reflection import (
    struct_field_count,
    struct_field_names,
    struct_field_types,
    get_type_name,
    get_base_type_name,
    is_struct_type,
    source_location,
)
from os.path import basename
from utils.numerics import max_finite, min_finite
from sys import exit
from math import clamp


fn cli_parse[T: Defaultable & Movable]() raises -> T:
    __comptime_assert is_struct_type[T]()

    # types
    comptime bool = get_type_name[Bool]()
    comptime str = get_type_name[String]()

    # index
    comptime int = get_type_name[Int]()
    comptime uint = get_type_name[UInt]()

    # ints
    comptime ints = {
        get_type_name[Int8](): DType.int8,
        get_type_name[Int16](): DType.int16,
        get_type_name[Int32](): DType.int32,
        get_type_name[Int64](): DType.int64,
        # get_type_name[UInt](): DType.uint,
        get_type_name[UInt8](): DType.uint8,
        get_type_name[UInt16](): DType.uint16,
        get_type_name[UInt32](): DType.uint32,
        get_type_name[UInt64](): DType.uint64,
    }

    # floats
    comptime floats = {
        get_type_name[Float16](): DType.float16,
        get_type_name[Float32](): DType.float32,
        get_type_name[Float64](): DType.float64,
    }

    var args = argv()
    var instance = T()

    # help
    for arg in args:
        if arg in ["--help", "-h"]:
            _print_help[T]()
            exit(0)

    comptime field_count = struct_field_count[T]()
    comptime field_names = struct_field_names[T]()
    comptime field_types = struct_field_types[T]()

    var i = 1
    while i < len(args):
        var arg = args[i]

        if not arg.startswith("--"):
            i += 1
            continue

        var arg_name = arg.strip("-")

        if arg_name not in materialize[field_names]():
            raise Error("Warning: Unknown arg --{}".format(arg_name))

        @parameter
        for idx in range(field_count):
            comptime field_name = field_names[idx]
            comptime field_type = field_types[idx]
            comptime field_type_name = get_type_name[field_type]()

            if arg_name != field_name:
                continue

            ref field = __struct_field_ref(idx, instance)

            @parameter
            if field_type_name == bool:
                field = rebind[type_of(field)](~rebind[Bool](field))
                break

            var val: StringSlice[StaticConstantOrigin]
            if i + 1 < len(args):
                i += 1
                val = args[i]
            else:
                raise Error("Arg -- {} requires a value".format(arg_name))

            @parameter
            if field_type_name == str:
                field = rebind[type_of(field)](String(val))
                break

            # index types
            elif field_type_name == int:
                field = rebind[type_of(field)](atol(val))
                break

            elif field_type_name == uint:
                field = rebind[type_of(field)](UInt(atol(val)))
                break

            # ints
            elif field_type_name in ints:
                comptime dtype = ints.get(field_type_name).value()
                field = rebind[type_of(field)](
                    _parse_int[dtype](val, field_name)
                )
                break

            # floats
            elif field_type_name in floats:
                comptime dtype = floats.get(field_type_name).value()
                field = rebind[type_of(field)](
                    _parse_float[dtype](val, field_name)
                )
                break

            else:
                raise Error(
                    "Cannot parse CLI value for unknown"
                    " type: {}, value:{}".format(field_type_name, val)
                )
        i += 1

    return instance^


fn _parse_int[
    type: DType
](val: StringSlice[StaticConstantOrigin], name: String) raises -> Scalar[type]:
    var raw = Int128(atol(val))
    comptime min = Int128(min_finite[type]())
    comptime max = Int128(max_finite[type]())
    if not min <= raw <= max:
        raise Error(
            "Value {} for --{}  is out of bounds for {} : [{}, {}]".format(
                val, name, type, min, max
            )
        )
    return Scalar[type](raw)


fn _parse_float[
    type: DType
](val: StringSlice[StaticConstantOrigin], name: String) raises -> Scalar[type]:
    var raw = atof(val)
    comptime min = Float64(min_finite[type]())
    comptime max = Float64(max_finite[type]())
    if not min <= raw <= max:
        raise Error(
            "Value {} for --{}  is out of bounds for {} : [{}, {}]".format(
                val, name, type, min, max
            )
        )
    return Scalar[type](raw)


fn _print_help[T: Defaultable]() raises:
    print("Command Line Parser Help (-h or --help)")
    var loc = source_location()
    var file_name = basename(loc.file_name)
    print("Usage: mojo {} [options]".format(file_name))
    print("\nOptions:")

    comptime field_names = struct_field_names[T]()
    comptime field_types = struct_field_types[T]()
    comptime field_count = struct_field_count[T]()

    var default = T()

    @parameter
    for i in range(field_count):
        comptime field_name = field_names[i]
        comptime field_type = field_types[i]
        comptime field_type_name = get_type_name[field_type]()

        var tn: String = field_type_name
        if "SIMD" in field_type_name:
            tn = field_type_name[11:].split(",")[0]
            tn = tn.replace("f", "F").replace("u", "U").replace("i", "I")

        ref val = __struct_field_ref(i, default)

        fn _get_padding[S: Stringable](a: S, max_pad_len: Int = 10) -> String:
            var len = len(String(a))
            return " " * clamp(max_pad_len - len, 1, max_pad_len)

        var pad_name = _get_padding(field_name)
        var pad_def = _get_padding(tn)

        @parameter
        if not conforms_to(field_type, Writable):
            raise "type is not Writable = unable to print help"

        print(
            "  --{} {}: {} {}(default: {})".format(
                field_name, pad_name, tn, pad_def, trait_downcast[Writable](val)
            )
        )
