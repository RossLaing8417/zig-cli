# zig-cli

Package for building command line apps in zig

Inspired by [urfave/cli](https://github.com/urfave/cli) (and partly [spf13/cobra](https://github.com/spf13/cobra))

## Features
- long and short flags: `--foo` and `-f`
- concatinating short flags: `-abc` same as `-a -b -c`
- optional usage of `=`: `--foo bar` or `--foo=bar`
- binds to a given variable address and automatically sets the value
- binds to a slice to automatically append values
- automatic help and version flag
- prints shorted help when missing sub command arg
- init and deinit actions
- pre and post command execute actions
- passes context to the called functions (including args found after parsing `--`)
