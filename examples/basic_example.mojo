from moclap import cli_parse


@fieldwise_init
struct Config(Copyable, Defaultable, Writable):
    var name: String
    var port: Int
    var verbose: Bool
    var timeout: Float64
    var size: UInt

    fn __init__(out self):
        self.name = "app"
        self.port = 8080
        self.verbose = False
        self.timeout = 30.0
        self.size = 13


fn main() raises:
    var config = cli_parse[Config]()

    print(config)
