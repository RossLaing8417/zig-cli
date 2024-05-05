# zig-cli

Package for building command line apps in zig

Inspired by [urfave/cli](https://github.com/urfave/cli) and partly [spf13/cobra](https://github.com/spf13/cobra)

Also following [clig.dev](https://clig.dev/) as a sort of standard guideline

## Features
 - long and short flags: `--foo` and `-f`
 - concatinating short flags: `-abc` same as `-a -b -c`
 - optional usage of `=`: `--foo bar` or `--foo=bar`
 - binds to a given variable address and automatically sets the value
 - passes context to the called functions
