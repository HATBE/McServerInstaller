# Mc Server Installer

``` bash
$ git clone https://github.com/HATBE/McServerInstaller .
$ chmod +x installer.sh
$ bash installer.sh
```

| Argument        | Description                               |
|-----------------|-------------------------------------------|
| --help          | prints help                               |
| --show-versions | prints all possible versions of minecraft |
| --silent        | no output to concsole                     |
| -r              | sets RAM (512 - 8192)MB (default= 1024)MB |
| -n              | sets name (default= srv1)                 |
| -v              | sets version (default= latest)            |
| -p              | sets port (default= 25565)                |
| -y              | dont ask questions                        |

Example:

``` bash
$ bash installer.sh -r 2048 -n server01 -v 1.17.1 -p 25567
```
