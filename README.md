# Moclap

Moclap is a `prototype` CLI argument parser for [Mojo](https://www.modular.com/mojo). This project was developed as an experiment to explore Mojo's reflection capabilities.

## Overview

The core objective of this project was to implement a "struct-first" CLI parser that requires zero manual mapping, similar to [clap](https://github.com/clap-rs/clap) in rust. By leveraging `reflection`, the parser inspects the provided configuration struct at compile time and generates the necessary logic to populate it. The config struct must be `Defaultable` to have defaults values.

## Current Prototype State

The parser currently supports:
- **Basic Types**: `String`, `Bool`, `Int`, `UInt`.
- **Fixed-width Integers**: `Int8` through `Int64`, `UInt8` through `UInt64`.
- **Floating Point**: `Float16`, `Float32`, `Float64`.
- **Boolean Toggles**: Flags flip the default state of a boolean using bitwise negation (`~`).
- **Help Generation**: Automatically generates a help menu based on the struct definition and default values provided in `__init__`.

## Example Usage

```python
from moclap import cli_parse

@fieldwise_init
struct Config(Copyable, Defaultable, Writable):
    var name: String
    var port: Int
    var verbose: Bool
    var timeout: Float64

    fn __init__(out self):
        self.name = "app"
        self.port = 8080
        self.verbose = False
        self.timeout = 30.0

fn main() raises:
    # Generates a parser specialized for the Config struct
    var config = cli_parse[Config]()

    # Use the parsed config
    print(config)
```

### Running the Example

Passing arguments:
```bash
mojo example.mojo --name "my-server" --port 9000 --verbose
```

Viewing the auto-generated help:
```bash
mojo example.mojo --help
```
**Output:**
```text
Command Line Parser Help (-h or --help)
Usage: [options]

Options:
  --name       : String     (default: app)
  --port       : Int        (default: 8080)
  --verbose    : Bool       (default: False)
  --timeout    : Float64    (default: 30.0)
```
