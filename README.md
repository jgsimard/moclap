# Moclap

Moclap is a `prototype` CLI argument parser for [Mojo](https://www.modular.com/mojo). This project was developed as an experiment to explore Mojo's reflection capabilities.

## Overview

The core objective of this project was to implement a "struct-first" CLI parser that requires zero manual mapping, similar to [clap](https://github.com/clap-rs/clap) in Rust. By leveraging `reflection`, the parser inspects the provided configuration struct at compile time and generates the necessary logic to populate it. The config struct must be `Defaultable` to provide default values.

## Current Prototype State

The parser currently supports:
- **Basic Types**: `String`, `Bool`, `Int`, `UInt`.
- **Fixed-width Integers**: `Int8` through `Int256`, `UInt8` through `UInt256`.
- **Floating Point**: `Float16`, `Float32`, `Float64`.
- **Boolean Flags**: A boolean flag sets its field to `True`.
- **Annotations**: `Command` and `Arg` metadata customize help text, long names, and short flags.
- **Help Generation**: Automatically generates a help menu based on the struct definition and default values provided in `__init__`.

## Example Usage

```python
from moclap import Arg, cli_parse

@fieldwise_init
struct Config(Defaultable, Writable):
    @__annotation(Arg(help="Application name.", short="n"))
    var name: String
    @__annotation(Arg(help="Port to listen on.", short="p"))
    var port: Int
    @__annotation(Arg(help="Enable verbose output.", short="v"))
    var verbose: Bool
    @__annotation(Arg(help="Request timeout in seconds."))
    var timeout: Float64
    @__annotation(Arg(help="Worker pool size.", long="pool-size"))
    var size: UInt

    def __init__(out self):
        self.name = "app"
        self.port = 8080
        self.verbose = False
        self.timeout = 30.0
        self.size = 13

def main() raises:
    # Generates a parser specialized for the Config struct
    var config = cli_parse[Config]()

    # Use the parsed config
    print(config)
```

### Running the Example

Passing arguments:
```bash
mojo example.mojo -n "my-server" --port 9000 -v
```

Viewing the auto-generated help:
```bash
mojo example.mojo --help
```
**Output:**
```text
Command Line Parser Help (-h or --help)
Usage: mojo moclap.mojo [options]

Run the example application.

Options:
-n, --name    : String     (default: app) Application name.
-p, --port    : Int        (default: 8080) Port to listen on.
-v, --verbose : Bool       (default: False) Enable verbose output.
--timeout     : Float64    (default: 30.0) Request timeout in seconds.
--pool-size   : UInt       (default: 13) Worker pool size.
```
