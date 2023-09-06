<h1 align="center">8086_genome_reader</h1>
<h4 align="center">An Intel 8086 assembler-based genome string reader.</h4>

<p align="center">
    <a href="#usage">Usage</a> •
    <a href="#license">License</a> •
    <a href="#contact">Contact</a>
</p>

## Usage

```sh
masm main.asm
```

```sh
link main.obj
```

```sh
main.exe -f <input_file> -o <output_file> -n <base_group_size> -<actg+>
```

### Options

* `-f`: Specify the input file.
* `-o`: Specify the output file (default is "a.out").
* `-n`: Specify the size of base groups (must be greater than or equal to 1).
* `-a`: Include base A in the output.
* `-t`: Include base T in the output.
* `-c`: Include base C in the output.
* `-g`: Include base G in the output.
* `-+`: Include the combination A+T and C+G in the output.

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

Bruno Samuel - <a href="https://www.linkedin.com/in/brunosag/" target="_new">LinkedIn</a> - <a href="mailto:bruno.samuel@ufrgs.br" target="_new">bruno.samuel@ufrgs.br</a>
